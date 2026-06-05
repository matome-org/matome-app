type JsonSchema = {
  $ref?: string;
  type?: string | string[];
  enum?: string[];
  required?: string[];
  properties?: Record<string, JsonSchema>;
  items?: JsonSchema;
  additionalProperties?: boolean | JsonSchema;
};

type Operation = {
  operationId?: string;
  "x-client-method"?: string;
  requestBody?: { $ref?: string };
  responses?: Record<string, { $ref?: string }>;
  parameters?: Array<{ $ref?: string }>;
};

type OpenApiSpec = {
  paths: Record<string, Record<string, Operation>>;
  components: {
    requestBodies: Record<string, { content: { "application/json": { schema: JsonSchema } } }>;
    responses: Record<string, { content?: { "application/json": { schema: JsonSchema } } }>;
    schemas: Record<string, JsonSchema>;
  };
};

const specPath = new URL("../openapi/matome-core-api.json", import.meta.url);
const outPath = new URL("../src/index.ts", import.meta.url);
const spec = (await Bun.file(specPath).json()) as OpenApiSpec;

const requiredPaths = [
  "/health",
  "/api/auth/register",
  "/api/auth/login",
  "/api/auth/refresh",
  "/api/auth/logout",
  "/api/auth/me",
  "/api/spaces",
  "/api/spaces/search",
  "/api/spaces/{id}",
  "/api/recordings",
  "/api/recordings/search",
  "/api/recordings/{id}",
  "/api/recordings/{id}/download-url",
  "/api/recordings/{id}/process",
];

for (const path of requiredPaths) {
  if (!spec.paths[path]) {
    throw new Error(`OpenAPI spec is missing required path ${path}`);
  }
}

const refName = (ref: string) => {
  const name = ref.split("/").pop();

  if (!name) {
    throw new Error(`Invalid OpenAPI ref ${ref}`);
  }

  return name;
};

const schemaToType = (schema: JsonSchema): string => {
  if (schema.$ref) {
    return refName(schema.$ref);
  }

  if (schema.enum?.length) {
    return schema.enum.map((value) => JSON.stringify(value)).join(" | ");
  }

  if (Array.isArray(schema.type)) {
    return schema.type.map((type) => schemaToType({ ...schema, type })).join(" | ");
  }

  switch (schema.type) {
    case "array":
      return `${schemaToType(schema.items ?? {})}[]`;
    case "boolean":
      return "boolean";
    case "integer":
    case "number":
      return "number";
    case "null":
      return "null";
    case "object": {
      if (schema.additionalProperties && !schema.properties) {
        const valueType =
          schema.additionalProperties === true
            ? "unknown"
            : schemaToType(schema.additionalProperties);

        return `Record<string, ${valueType}>`;
      }

      const required = new Set(schema.required ?? []);
      const props = Object.entries(schema.properties ?? {}).map(([key, value]) => {
        const optional = required.has(key) ? "" : "?";

        return `  ${JSON.stringify(key)}${optional}: ${schemaToType(value)};`;
      });

      if (schema.additionalProperties) {
        const valueType =
          schema.additionalProperties === true
            ? "unknown"
            : schemaToType(schema.additionalProperties);
        props.push(`  [key: string]: ${valueType};`);
      }

      return props.length ? `{\n${props.join("\n")}\n}` : "Record<string, never>";
    }
    case "string":
      return "string";
    default:
      return "unknown";
  }
};

const resolveRequestBody = (operation: Operation): string | undefined => {
  const ref = operation.requestBody?.$ref;

  if (!ref) {
    return undefined;
  }

  return schemaToType(spec.components.requestBodies[refName(ref)].content["application/json"].schema);
};

const resolveSuccessResponse = (operation: Operation): string => {
  const successStatus = Object.keys(operation.responses ?? {})
    .filter((status) => status.startsWith("2"))
    .sort()[0];

  if (!successStatus) {
    throw new Error(`Operation ${operation.operationId ?? "unknown"} has no 2xx response`);
  }

  const response = operation.responses?.[successStatus];

  if (!response?.$ref) {
    return "void";
  }

  const schema = spec.components.responses[refName(response.$ref)].content?.["application/json"]?.schema;

  return schema ? schemaToType(schema) : "void";
};

const operations = Object.entries(spec.paths)
  .flatMap(([path, methods]) =>
    Object.entries(methods).map(([httpMethod, operation]) => ({
      path,
      httpMethod: httpMethod.toUpperCase(),
      operation,
    }))
  )
  .filter(({ operation }) => operation["x-client-method"])
  .sort((a, b) => (a.operation["x-client-method"] ?? "").localeCompare(b.operation["x-client-method"] ?? ""));

const schemaTypes = Object.keys(spec.components.schemas)
  .sort()
  .map((name) => `export type ${name} = ${schemaToType(spec.components.schemas[name])};`)
  .join("\n\n");

const clientMethods = operations
  .map(({ path, httpMethod, operation }) => {
    if (!operation.operationId) {
      throw new Error(`Client operation ${operation["x-client-method"]} is missing operationId`);
    }

    const methodName = operation["x-client-method"]!;
    const requestType = resolveRequestBody(operation);
    const responseType = resolveSuccessResponse(operation);
    const args: string[] = [];
    const callArgs: string[] = [JSON.stringify(path), JSON.stringify(httpMethod)];

    if (path.includes("{id}")) {
      args.push("id: number");
      callArgs.push("{ id }");
    } else {
      callArgs.push("undefined");
    }

    if (operation.parameters?.some((parameter) => parameter.$ref?.endsWith("/SearchQuery"))) {
      args.push("params?: SearchParams");
      callArgs.push("params");
    } else {
      callArgs.push("undefined");
    }

    if (requestType) {
      args.push(`body: ${requestType}`);
      callArgs.push("body");
    } else {
      callArgs.push("undefined");
    }

    return [
      `    ${methodName}(${args.join(", ")}): Promise<${responseType}> {`,
      `      return request<${responseType}>(${callArgs.join(", ")});`,
      "    }",
    ].join("\n");
  })
  .join(",\n");

const source = [
  "/* eslint-disable */",
  "// Generated by packages/api-client/scripts/generate-api-client.ts from openapi/matome-core-api.json.",
  "// Do not edit this file directly. Run `bun run generate:api` from the workspace root.",
  "",
  schemaTypes,
  "",
  "export type SearchParams = {",
  "  q?: string;",
  "};",
  "",
  "export type MatomeApiClientConfig = {",
  "  baseUrl: string;",
  "  accessToken?: string | (() => string | undefined | Promise<string | undefined>);",
  "  fetch?: typeof fetch;",
  "};",
  "",
  "export class MatomeApiError<TBody = unknown> extends Error {",
  "  readonly status: number;",
  "  readonly body: TBody;",
  "",
  "  constructor(status: number, body: TBody) {",
  "    super(`Matome API request failed with status ${status}`);",
  "    this.name = \"MatomeApiError\";",
  "    this.status = status;",
  "    this.body = body;",
  "  }",
  "}",
  "",
  "export function createMatomeApiClient(config: MatomeApiClientConfig) {",
  "  const fetchImpl = config.fetch ?? fetch;",
  "",
  "  const request = async <TResponse>(",
  "    pathTemplate: string,",
  "    method: string,",
  "    pathParams?: Record<string, string | number>,",
  "    queryParams?: SearchParams,",
  "    body?: unknown",
  "  ): Promise<TResponse> => {",
  "    const path = Object.entries(pathParams ?? {}).reduce(",
  "      (value, [key, pathValue]) => value.replace(`{${key}}`, encodeURIComponent(String(pathValue))),",
  "      pathTemplate",
  "    );",
  "    const url = new URL(path, config.baseUrl.endsWith(\"/\") ? config.baseUrl : `${config.baseUrl}/`);",
  "",
  "    for (const [key, value] of Object.entries(queryParams ?? {})) {",
  "      if (value !== undefined) {",
  "        url.searchParams.set(key, value);",
  "      }",
  "    }",
  "",
  "    const token =",
  "      typeof config.accessToken === \"function\" ? await config.accessToken() : config.accessToken;",
  "    const headers = new Headers();",
  "",
  "    if (body !== undefined) {",
  "      headers.set(\"Content-Type\", \"application/json\");",
  "    }",
  "",
  "    if (token) {",
  "      headers.set(\"Authorization\", `Bearer ${token}`);",
  "    }",
  "",
  "    const response = await fetchImpl(url, {",
  "      method,",
  "      headers,",
  "      body: body === undefined ? undefined : JSON.stringify(body),",
  "    });",
  "",
  "    if (response.status === 204) {",
  "      return undefined as TResponse;",
  "    }",
  "",
  "    const responseBody = await response.json().catch(() => undefined);",
  "",
  "    if (!response.ok) {",
  "      throw new MatomeApiError(response.status, responseBody);",
  "    }",
  "",
  "    return responseBody as TResponse;",
  "  };",
  "",
  "  return {",
  clientMethods,
  "  };",
  "}",
  "",
  "export type MatomeApiClient = ReturnType<typeof createMatomeApiClient>;",
  "",
].join("\n");

await Bun.write(outPath, source);

console.log(`Generated ${outPath.pathname} from ${specPath.pathname}`);
