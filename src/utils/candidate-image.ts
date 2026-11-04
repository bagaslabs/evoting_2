const IMAGE_TYPES = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
]);

export const MAX_CANDIDATE_IMAGE_SIZE = 5 * 1024 * 1024;

export function getCandidateImageExtension(file: Pick<File, "type" | "size">) {
  const extension = IMAGE_TYPES.get(file.type);
  if (!extension) {
    throw new Error("Foto harus berformat JPG, PNG, atau WebP.");
  }
  if (file.size > MAX_CANDIDATE_IMAGE_SIZE) {
    throw new Error("Ukuran foto maksimal 5 MB.");
  }
  return extension;
}

export function getCandidateStoragePath(
  imageUrl: string | null | undefined,
  projectUrl: string | undefined,
) {
  if (!imageUrl || !projectUrl) return null;

  try {
    const image = new URL(imageUrl);
    const project = new URL(projectUrl);
    const prefix = "/storage/v1/object/public/candidate-photos/";
    if (image.origin !== project.origin || !image.pathname.startsWith(prefix)) {
      return null;
    }

    const path = decodeURIComponent(image.pathname.slice(prefix.length));
    if (!path || path.split("/").some((part) => !part || part === "." || part === "..")) {
      return null;
    }
    return path;
  } catch {
    return null;
  }
}
