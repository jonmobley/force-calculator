declare namespace Cloudflare {
  interface Env {
    /** A secret in production; a fixed value under test (see `vitest.config.mts`). */
    WRITE_TOKEN: string;
    /** Test-only binding carrying the D1 migrations, defined in `vitest.config.mts`. */
    TEST_MIGRATIONS: import("cloudflare:test").D1Migration[];
  }
}
