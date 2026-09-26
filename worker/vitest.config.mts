import path from "node:path";
import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig(async () => {
  const migrations = await readD1Migrations(
    path.join(import.meta.dirname, "migrations"),
  );

  return {
    plugins: [
      cloudflareTest({
        wrangler: { configPath: "./wrangler.jsonc" },
        miniflare: {
          bindings: {
            // Applied by `test/apply-migrations.ts` before any test file runs.
            TEST_MIGRATIONS: migrations,
            // Stands in for the `WRITE_TOKEN` secret, which only exists in production.
            WRITE_TOKEN: "legacy-service-token",
          },
        },
      }),
    ],
    test: {
      include: ["test/**/*.spec.ts"],
      setupFiles: ["./test/apply-migrations.ts"],
    },
  };
});
