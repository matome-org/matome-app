const fs = require("fs");
const path = require("path");
const { AndroidConfig, withAndroidManifest, withDangerousMod } = require("@expo/config-plugins");

const BACKUP_RULES_RESOURCE = "@xml/secure_store_backup_rules";
const DATA_EXTRACTION_RESOURCE = "@xml/secure_store_data_extraction_rules";

const sensitiveExcludes = [
  // SecureStore entries cannot be restored after uninstall because their keys are removed.
  { domain: "sharedpref", path: "SecureStore" },
  // Expo audio persists segment_*.m4a and recording_*.mp3 under documentDirectory.
  { domain: "file", path: "." },
  // SQLite holds transcripts, summaries, notes, draft segment paths, and recording paths.
  { domain: "database", path: "matome.db" },
  { domain: "database", path: "matome.db-journal" },
  { domain: "database", path: "matome.db-wal" },
  { domain: "database", path: "matome.db-shm" },
];

const excludeTags = sensitiveExcludes
  .map(({ domain, path }) => `    <exclude domain="${domain}" path="${path}"/>`)
  .join("\n");

const backupRulesXml = `<?xml version="1.0" encoding="utf-8"?>
<full-backup-content>
${excludeTags}
</full-backup-content>
`;

const dataExtractionRulesXml = `<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup>
${excludeTags}
  </cloud-backup>
  <device-transfer>
${excludeTags}
  </device-transfer>
</data-extraction-rules>
`;

const writeXmlResource = (projectRoot, fileName, contents) => {
  const xmlDir = path.join(projectRoot, "android", "app", "src", "main", "res", "xml");
  fs.mkdirSync(xmlDir, { recursive: true });
  fs.writeFileSync(path.join(xmlDir, fileName), contents);
};

const withAndroidBackupPrivacy = (config) => {
  config = withAndroidManifest(config, (modConfig) => {
    const application = AndroidConfig.Manifest.getMainApplicationOrThrow(modConfig.modResults);
    application.$["android:allowBackup"] = "true";
    application.$["android:fullBackupContent"] = BACKUP_RULES_RESOURCE;
    application.$["android:dataExtractionRules"] = DATA_EXTRACTION_RESOURCE;
    return modConfig;
  });

  return withDangerousMod(config, [
    "android",
    (modConfig) => {
      writeXmlResource(modConfig.modRequest.projectRoot, "secure_store_backup_rules.xml", backupRulesXml);
      writeXmlResource(
        modConfig.modRequest.projectRoot,
        "secure_store_data_extraction_rules.xml",
        dataExtractionRulesXml,
      );
      return modConfig;
    },
  ]);
};

module.exports = withAndroidBackupPrivacy;
