import { formatCommandOutput, routeFromArgs } from "./router.mjs";

const ROUTE_EVENT = "omp-mr-router:route";
const DELIVER_EVENT = "omp-mr-router:deliver";

export default function registerOmpMrRouter(pi) {
  pi.registerCommand("mr-route", {
    description: "Classify MR delivery risk and print the selected builder/reviewer route.",
    handler: async (args, ctx) => {
      const route = routeFromArgs(args, "mr-route");
      emitRouteEvent(pi, ROUTE_EVENT, route);
      sendMarkdown(pi, formatCommandOutput(args, "mr-route"));
      notify(ctx, route.highRisk ? "MR route: high-risk builder selected" : "MR route: normal builder selected");
    },
  });

  pi.registerCommand("mr-deliver", {
    description: "Emit a parent-safe MR delivery instruction using the selected routed agents.",
    handler: async (args, ctx) => {
      const route = routeFromArgs(args, "mr-deliver");
      emitRouteEvent(pi, DELIVER_EVENT, route);
      sendMarkdown(pi, formatCommandOutput(args, "mr-deliver"));
      notify(ctx, "MR delivery instruction emitted");
    },
  });
}

function emitRouteEvent(pi, eventName, route) {
  if (typeof pi?.events?.emit !== "function") return;
  pi.events.emit(eventName, route);
}

function sendMarkdown(pi, content) {
  if (typeof pi?.sendMessage === "function") {
    pi.sendMessage({ content, display: true });
    return;
  }
  if (typeof pi?.messages?.send === "function") {
    pi.messages.send({ content, display: true });
  }
}

function notify(ctx, message) {
  if (typeof ctx?.ui?.notify !== "function") return;
  ctx.ui.notify(message, "info");
}
