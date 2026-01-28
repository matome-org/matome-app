import type { AxiosInstance } from 'axios';
import type { Any } from 'ts-toolbelt';

export type AnyObjectArray = Record<Any.Key, unknown>[]
export type Methods = 'get' | 'post' | 'put' | 'delete'
export type ModifiedRequests = { [K in Methods]: <T = AnyObjectArray>(...args: Parameters<AxiosInstance[K]>) => Promise<T> }
