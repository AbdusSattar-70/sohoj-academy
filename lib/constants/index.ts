const getBaseUrl = () =>
  process.env.NODE_ENV === "production"
    ? "https://f-ledger-backend.vercel.app"
    : "http://localhost:3001";

export const API_ROUTES = {
  AUTH_USER: `${getBaseUrl()}/api/auth/whoami`,
};

export const RoleEnum = ["leader", "co_leader", "member"] as const;

export const ROUTES = {
  ROOT: "/",
  AUTH: "/auth",
  SIGN_IN: "/auth/sign-in",
  SIGN_UP: "/auth/sign-up",
  DASHBOARD: "/dashboard",
  DB_SYNC_ERROR: "/db-sync-error",
};

// Typing sentences
export const SENTENCES = [
  "Track every transaction with confidence",
  "Keep finances transparent and organized",
  "Build a financial record you can trust",
  "Manage funds and accounts effortlessly",
  "Account for every taka",
  "Maintain a complete financial history",
  "Make better decisions with clarity",
];

export const STATUS = {
  ONLINE: "online",
  OFFLINE: "offline",
  BACK_ONLINE: "back-online",
} as const;

export const FEEDBACK_MSG = {
  [STATUS.OFFLINE]: "Opps! You are offline.",
  [STATUS.BACK_ONLINE]: "You're back online!",
} as const;
