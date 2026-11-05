import type { RouteObject } from "react-router";
import AdminPage from "../pages/AdminPage";
import AdminQueuePage from "../pages/AdminQueuePage";
import DevicePage from "../pages/DevicePage";
import LandingPage from "../pages/LandingPage";
import NotFoundPage from "../pages/NotFoundPage";
import PublicQueuePage from "../pages/PublicQueuePage";
import ResultsPage from "../pages/ResultsPage";

export const routes: RouteObject[] = [
  {
    path: "/",
    Component: LandingPage,
  },
  {
    path: "/admin",
    Component: AdminPage,
  },
  {
    path: "/admin/login",
    Component: AdminPage,
  },
  {
    path: "/admin/queue",
    Component: AdminQueuePage,
  },
  {
    path: "/device",
    Component: DevicePage,
  },
  {
    path: "/antrian",
    Component: PublicQueuePage,
  },
  {
    path: "/results",
    Component: ResultsPage,
  },
  {
    path: "/results/:roundSlug",
    Component: ResultsPage,
  },
  {
    path: "*",
    Component: NotFoundPage,
  },
];
