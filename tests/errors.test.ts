import { describe, expect, test } from "bun:test";
import { getErrorMessage, isDeviceBoundError } from "../src/utils/errors";

describe("getErrorMessage", () => {
  test("returns the message from a Supabase/PostgREST error object", () => {
    expect(
      getErrorMessage({
        code: "PGRST202",
        message: "Could not find the function in the schema cache",
        details: "The function may not have been created.",
        hint: "Reload the schema cache.",
      }),
    ).toBe(
      "Could not find the function in the schema cache The function may not have been created. Reload the schema cache.",
    );
  });

  describe("isDeviceBoundError", () => {
    test("identifies a token already claimed by another device", () => {
      expect(isDeviceBoundError({ code: "55000" })).toBe(true);
      expect(isDeviceBoundError({ code: "28000" })).toBe(false);
      expect(isDeviceBoundError(null)).toBe(false);
    });
  });

  test("preserves Error and string messages", () => {
    expect(getErrorMessage(new Error("Failure"))).toBe("Failure");
    expect(getErrorMessage("Failure")).toBe("Failure");
  });

  test("uses a fallback for values without a message", () => {
    expect(getErrorMessage({ code: "UNKNOWN" })).toBe(
      "Terjadi kesalahan. Silakan coba kembali.",
    );
  });
});
