import {z} from 'zod';
/** PostgreSQL uuid accepts canonical hexadecimal IDs without RFC version/variant restrictions.
 * Deterministic starter IDs must use this same contract as generated database IDs.
 * Request tokens use z.uuid() separately because the browser generates crypto.randomUUID().
 */
export const databaseId=z.guid();
