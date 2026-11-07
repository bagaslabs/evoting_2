import { useEffect, useState } from "react";
import type { ChangeEvent, FormEvent } from "react";
import type { Candidate, CandidateInput } from "../../types/election";
import { getCandidateImageExtension } from "../../utils/candidate-image";
import { getErrorMessage } from "../../utils/errors";
import { safeImageUrl } from "../../utils/format";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Checkbox";
import { Field } from "../ui/Field";
import { Input } from "../ui/Input";
import { Notice } from "../ui/Notice";
import { Textarea } from "../ui/Textarea";

interface CandidateFormProps {
  candidate?: Candidate;
  onSubmit: (input: CandidateInput, existing: Candidate | null) => Promise<void>;
  onDelete?: (candidate: Candidate) => void;
}

export function CandidateForm({
  candidate,
  onSubmit,
  onDelete,
}: CandidateFormProps) {
  const [name, setName] = useState(candidate?.name ?? "");
  const [vision, setVision] = useState(candidate?.vision ?? "");
  const [mission, setMission] = useState(candidate?.mission ?? "");
  const [imageUrl, setImageUrl] = useState(candidate?.image_url ?? "");
  const [active, setActive] = useState(candidate?.active ?? true);
  const [photo, setPhoto] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState("");
  const [removePhoto, setRemovePhoto] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!photo) {
      setPreviewUrl("");
      return;
    }

    const url = URL.createObjectURL(photo);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [photo]);

  const previewImage = removePhoto && !photo ? "" : previewUrl || safeImageUrl(imageUrl);

  function handlePhotoChange(event: ChangeEvent<HTMLInputElement>) {
    const file = event.currentTarget.files?.[0] ?? null;
    setError(null);
    setRemovePhoto(false);

    if (!file) {
      setPhoto(null);
      return;
    }

    try {
      getCandidateImageExtension(file);
      setPhoto(file);
    } catch (photoError) {
      setPhoto(null);
      setError(getErrorMessage(photoError));
      event.currentTarget.value = "";
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (!name.trim()) {
      setError("Nama kandidat wajib diisi.");
      return;
    }

    setBusy(true);
    setError(null);
    try {
      await onSubmit(
        {
          id: candidate?.id ?? null,
          name: name.trim(),
          vision,
          mission,
          imageUrl: removePhoto && !photo ? "" : imageUrl.trim(),
          active,
          photo,
          removePhoto,
        },
        candidate ?? null,
      );

      if (!candidate) {
        setName("");
        setVision("");
        setMission("");
        setImageUrl("");
        setActive(true);
        setPhoto(null);
        setRemovePhoto(false);
        form.reset();
      }
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="candidate-form card" onSubmit={handleSubmit}>
      <div className="candidate-form-heading">
        {candidate?.image_url && (
          <img
            className="candidate-thumb"
            src={safeImageUrl(candidate.image_url)}
            alt=""
          />
        )}
        <strong>{candidate ? "Edit kandidat" : "Tambah kandidat"}</strong>
      </div>

      <Field label="Nama kandidat" htmlFor={`candidate-name-${candidate?.id ?? "new"}`}>
        <Input
          id={`candidate-name-${candidate?.id ?? "new"}`}
          value={name}
          onChange={(event) => setName(event.currentTarget.value)}
          required
        />
      </Field>

      <Field label="Upload foto" htmlFor={`candidate-photo-${candidate?.id ?? "new"}`}>
        <Input
          id={`candidate-photo-${candidate?.id ?? "new"}`}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          onChange={handlePhotoChange}
        />
      </Field>
      <p className="muted small photo-help">Format JPG, PNG, atau WebP · maksimal 5 MB.</p>

      <Field label="Link foto (opsional)" htmlFor={`candidate-image-${candidate?.id ?? "new"}`}>
        <Input
          id={`candidate-image-${candidate?.id ?? "new"}`}
          type="url"
          value={imageUrl}
          onChange={(event) => {
            setImageUrl(event.currentTarget.value);
            setRemovePhoto(false);
          }}
          placeholder="https://…"
        />
      </Field>

      {candidate?.image_url && (
        <Checkbox
          label="Hapus foto saat ini"
          checked={removePhoto}
          onChange={(event) => setRemovePhoto(event.currentTarget.checked)}
        />
      )}

      <Field label="Visi" htmlFor={`candidate-vision-${candidate?.id ?? "new"}`}>
        <Textarea
          id={`candidate-vision-${candidate?.id ?? "new"}`}
          rows={2}
          value={vision}
          onChange={(event) => setVision(event.currentTarget.value)}
        />
      </Field>

      <Field label="Misi" htmlFor={`candidate-mission-${candidate?.id ?? "new"}`}>
        <Textarea
          id={`candidate-mission-${candidate?.id ?? "new"}`}
          rows={2}
          value={mission}
          onChange={(event) => setMission(event.currentTarget.value)}
        />
      </Field>

      {candidate && (
        <>
          <Checkbox
            label="Kandidat aktif"
            checked={active}
            onChange={(event) => setActive(event.currentTarget.checked)}
          />
          <p className="muted small">
            {candidate.votes ?? 0} suara · {candidate.percentage ?? 0}%
          </p>
        </>
      )}

      <div className="candidate-preview">
        <p className="preview-label">Pratinjau di halaman voting</p>
        <CandidatePreview
          name={name}
          vision={vision}
          mission={mission}
          imageUrl={previewImage}
        />
      </div>

      <Notice kind="error">{error}</Notice>
      <div className="button-row">
        <Button type="submit" variant="secondary" disabled={busy}>
          {busy ? "Menyimpan…" : candidate ? "Simpan perubahan" : "Tambah kandidat"}
        </Button>
        {candidate && onDelete && (
          <Button
            type="button"
            variant="danger"
            size="sm"
            onClick={() => onDelete(candidate)}
          >
            Hapus kandidat
          </Button>
        )}
      </div>
    </form>
  );
}

interface CandidatePreviewProps {
  name: string;
  vision: string;
  mission: string;
  imageUrl: string;
}

function CandidatePreview({ name, vision, mission, imageUrl }: CandidatePreviewProps) {
  return (
    <article className="preview-card">
      {imageUrl ? (
        <img src={imageUrl} alt="" />
      ) : (
        <div className="preview-placeholder" aria-hidden="true">
          ?
        </div>
      )}
      <div className="preview-copy">
        <h3>{name || "Nama kandidat"}</h3>
        <strong>Visi</strong>
        <p>{vision || "-"}</p>
        <strong>Misi</strong>
        <p>{mission || "-"}</p>
      </div>
    </article>
  );
}
