import type { RouteObject } from "react-router";
import AdminPage from "../pages/AdminPage";
import DevicePage from "../pages/DevicePage";
import LandingPage from "../pages/LandingPage";
import NotFoundPage from "../pages/NotFoundPage";
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
    path: "/device",
    Component: DevicePage,
  },
  {
    path: "/results",
    Component: ResultsPage,
  },
  {
    path: "*",
    Component: NotFoundPage,
  },
];
