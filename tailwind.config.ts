import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: {
          950: "#070a12",
          900: "#0b101c",
          800: "#111827",
          700: "#1b2536",
        },
        brand: {
          400: "#5eead4",
          500: "#14b8a6",
          600: "#0d9488",
        },
        gain: "#22c55e",
        loss: "#ef4444",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        mono: ["ui-monospace", "SFMono-Regular", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
