import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  base: "/Asteria/",
  plugins: [react()],
  build: { sourcemap: false, chunkSizeWarningLimit: 650 },
  server: { host: "127.0.0.1" },
});
