import { describe, expect, test } from "bun:test";
import {
  getCandidateImageExtension,
  getCandidateStoragePath,
  MAX_CANDIDATE_IMAGE_SIZE,
} from "../src/utils/candidate-image";

describe("candidate image helpers", () => {
  test("accepts supported photo formats only", () => {
    expect(getCandidateImageExtension({ type: "image/jpeg", size: 10 })).toBe("jpg");
    expect(getCandidateImageExtension({ type: "image/png", size: 10 })).toBe("png");
    expect(getCandidateImageExtension({ type: "image/webp", size: 10 })).toBe("webp");
    expect(() =>
      getCandidateImageExtension({ type: "image/svg+xml", size: 10 }),
    ).toThrow(/JPG, PNG, atau WebP/);
    expect(() =>
      getCandidateImageExtension({
        type: "image/jpeg",
        size: MAX_CANDIDATE_IMAGE_SIZE + 1,
      }),
    ).toThrow(/maksimal 5 MB/);
  });

  test("only extracts object paths from this project candidate photo bucket", () => {
    const projectUrl = "https://project.supabase.co";

    expect(
      getCandidateStoragePath(
        "https://project.supabase.co/storage/v1/object/public/candidate-photos/candidate-1/photo.jpg",
        projectUrl,
      ),
    ).toBe("candidate-1/photo.jpg");

    expect(
      getCandidateStoragePath(
        "https://other.supabase.co/storage/v1/object/public/candidate-photos/photo.jpg",
        projectUrl,
      ),
    ).toBeNull();

    expect(
      getCandidateStoragePath(
        "https://project.supabase.co/storage/v1/object/public/other-bucket/photo.jpg",
        projectUrl,
      ),
    ).toBeNull();
  });
});
