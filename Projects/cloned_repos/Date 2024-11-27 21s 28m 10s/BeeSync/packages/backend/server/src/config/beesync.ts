/* eslint-disable @typescript-eslint/no-non-null-assertion */
//
// ###############################################################
// ##                BeeSync Configuration System                ##
// ###############################################################
// Here is the file of all BeeSync configurations that will affect runtime behavior.
// Override any configuration here and it will be merged when starting the server.
// Any changes in this file won't take effect before server restarted.
//
//
// > Configurations merge order
//   1. load environment variables (`.env` if provided, and from system)
//   2. load `src/fundamentals/config/default.ts` for all default settings
//   3. apply `./BeeSync.ts` patches (this file)
//   4. apply `./BeeSync.env.ts` patches
//
//
// ###############################################################
// ##                       General settings                    ##
// ###############################################################
//
// /* The unique identity of the server */
// BeeSync.serverId = 'some-randome-uuid';
//
// /* The name of BeeSync Server, may show on the UI */
// BeeSync.serverName = 'Your Cool BeeSync Selfhosted Cloud';
//
// /* Whether the server is deployed behind a HTTPS proxied environment */
BeeSync.https = false;
// /* Domain of your server that your server will be available at */
BeeSync.host = 'localhost';
// /* The local port of your server that will listen on */
BeeSync.port = 3010;
// /* The sub path of your server */
// /* For example, if you set `BeeSync.path = '/BeeSync'`, then the server will be available at `${domain}/BeeSync` */
// BeeSync.path = '/BeeSync';
//
//
// ###############################################################
// ##                       Database settings                   ##
// ###############################################################
//
// /* The URL of the database where most of BeeSync server data will be stored in */
// BeeSync.db.url = 'postgres://user:passsword@localhost:5432/BeeSync';
//
//
// ###############################################################
// ##                   Server Function settings                ##
// ###############################################################
//
// /* Whether enable metrics and tracing while running the server */
// /* The metrics will be available at `http://localhost:9464/metrics` with [Prometheus] format exported */
// BeeSync.metrics.enabled = true;
//
// /* Authentication Settings */
// /* Whether allow anyone signup */
// BeeSync.auth.allowSignup = true;
//
// /* User Signup password limitation */
// BeeSync.auth.password = {
//   minLength: 8,
//   maxLength: 32,
// };
//
// /* How long the login session would last by default */
// BeeSync.auth.session = {
//   ttl: 15 * 24 * 60 * 60, // 15 days
// };
//
// /* GraphQL configurations that control the behavior of the Apollo Server behind */
// /* @see https://www.apollographql.com/docs/apollo-server/api/apollo-server */
// BeeSync.graphql = {
//   /* Path to mount GraphQL API */
//   path: '/graphql',
//   buildSchemaOptions: {
//     numberScalarMode: 'integer',
//   },
//   /* Whether allow client to query the schema introspection */
//   introspection: true,
//   /* Whether enable GraphQL Playground UI */
//   playground: true,
// }
//
// /* Doc Store & Collaberation */
// /* How long the buffer time of creating a new history snapshot when doc get updated */
// BeeSync.doc.history.interval = 1000 * 60 * 10; // 10 minutes
//
// /* Use `y-octo` to merge updates at the same time when merging using Yjs */
// BeeSync.doc.manager.experimentalMergeWithYOcto = true;
//
// /* How often the manager will start a new turn of merging pending updates into doc snapshot */
// BeeSync.doc.manager.updatePollInterval = 1000 * 3;
//
//
// ###############################################################
// ##                        Plugins settings                   ##
// ###############################################################
//
// /* Redis Plugin */
// /* Provide caching and session storing backed by Redis. */
// /* Useful when you deploy BeeSync server in a cluster. */
// BeeSync.plugins.use('redis', {
//   /* override options */
// });
//
//
// /* Payment Plugin */
// BeeSync.plugins.use('payment', {
//   stripe: { keys: {}, apiVersion: '2023-10-16' },
// });
//
//
// /* Cloudflare R2 Plugin */
// /* Enable if you choose to store workspace blobs or user avatars in Cloudflare R2 Storage Service */
// BeeSync.plugins.use('cloudflare-r2', {
//   accountId: '',
//   credentials: {
//     accessKeyId: '',
//     secretAccessKey: '',
//   },
// });
//
// /* AWS S3 Plugin */
// /* Enable if you choose to store workspace blobs or user avatars in AWS S3 Storage Service */
// BeeSync.plugins.use('aws-s3', {
//  credentials: {
//    accessKeyId: '',
//    secretAccessKey: '',
// })
// /* Update the provider of storages */
// BeeSync.storage.storages.blob.provider = 'r2';
// BeeSync.storage.storages.avatar.provider = 'r2';
//
// /* OAuth Plugin */
// BeeSync.plugins.use('oauth', {
//   providers: {
//     github: {
//       clientId: '',
//       clientSecret: '',
//       // See https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
//       args: {
//         scope: 'user',
//       },
//     },
//     google: {
//       clientId: '',
//       clientSecret: '',
//       args: {
//         // See https://developers.google.com/identity/protocols/oauth2
//         scope: 'openid email profile',
//         promot: 'select_account',
//         access_type: 'offline',
//       },
//     },
//   },
// });
