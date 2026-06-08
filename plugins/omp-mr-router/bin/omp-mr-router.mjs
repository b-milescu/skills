#!/usr/bin/env node
import { formatCommandOutput } from "../src/router.mjs";

const [commandToken = "route", ...rest] = process.argv.slice(2);
const command = commandToken === "deliver" || commandToken === "mr-deliver" ? "mr-deliver" : "mr-route";
const args = commandToken === "route" || commandToken === "mr-route" || commandToken === "deliver" || commandToken === "mr-deliver"
  ? rest.join(" ")
  : process.argv.slice(2).join(" ");

process.stdout.write(formatCommandOutput(args, command));
