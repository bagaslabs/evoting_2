# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Primary users are students of Teknik Elektro, Universitas Jember, voting at a shared kiosk on election day. They arrive in a queue, identify themselves with a device token and NIM, review candidate biodata, cast one vote, and log out so the next voter can use the same device.

## Product Purpose

The product runs the election for Ketua Angkatan Teknik Elektro at Universitas Jember. It exists to move the voter queue quickly while guaranteeing one verified vote per eligible student and an outcome everyone can trust. Success means voters complete the kiosk flow fast, without double votes or identity confusion, and accept the published result as legitimate.

## Positioning

Voting is tied to a managed physical device and a one-time device token, not to a student's personal phone or account. Admins assign the next voter to each device from a central roster, so the kiosk can be handed from student to student with identity verification and auditability built into the flow.

## Operating Context

Election Day is a supervised, in-person event with a queue of students and a set of shared voting devices. A superadmin operates a dashboard to control election status (open, pause, resume, close), manage devices and their tokens, maintain the voter roster, manage candidates and photos, publish results, and review the audit log. Voters use the device flow: token entry, NIM verification, biodata, ballot, confirmation, a five-second countdown, then device sign-out. Copy is Indonesian because that is the language of the voters and organizers. The app depends on a live Supabase backend (auth, RPC, realtime, photo storage) and falls back to 15-second polling when realtime is unavailable.

## Capabilities and Constraints

Confirmed product capabilities: public landing page; public results page; superadmin login and dashboard; election status control; result publication and turnout settings; device management including activation, token rotation, copying, next-voter assignment, and forced unassignment; voter roster search, add, delete, JSON import, and queue ordering; candidate add/edit/activate/deactivate and photo upload/delete; audit log; admin password change; and the full device voting flow.

Technical constraints: React 19 + Vite + TypeScript frontend; Supabase for auth, RPC, realtime, and storage. The secret key is server-side only and must never reach the browser or `VITE_*` variables. All UI copy is Indonesian. The workflow is kiosk-based and shared-device, so each voter session must end cleanly before the next begins.

Undecided: exact election date, number of devices, expected voter count, and deployment target are not established in the repository and must not be invented.

## Brand Commitments

The product uses the name and identity of Ketua Angkatan Teknik Elektro, Universitas Jember. University and faculty branding must be preserved. Official logo/color assets and any formal identity rules are not present in the repository and remain to be confirmed.

## Evidence on Hand

Real product evidence consists of the repository's routes, components, services, Supabase migrations, and tests. Candidate photos are uploaded through the app's own storage; voter data is imported as real roster JSON. There are no testimonials, press mentions, benchmark numbers, or external case studies, and none should be fabricated.

## Product Principles

- One verified student, one vote: identity and device assignment must never allow a double vote.
- The queue wins: every voter-facing step should minimize time and hesitation at the kiosk.
- Trust is visible: status, turnout, auditability, and published results should be legible to organizers and voters.
- Operate under pressure: admins need clear recovery paths when a device, token, or assignment goes wrong mid-event.
- Speak Indonesian plainly: labels and messages use the voters' and organizers' everyday language.
