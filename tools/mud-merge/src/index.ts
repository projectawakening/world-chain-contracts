import { Command } from "commander";
import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";

const figlet = require("figlet");

console.log(figlet.textSync("Mud Merge CLI"));

const program = new Command();
program
  .version("1.0.0")
  .description("An CLI for merging multiple MUD projects into a single one")
  .requiredOption(
    "-p, --projects  <items>",
    "A comma separated list of projects to include",
  )
  .parse(process.argv);

const options = program.opts();

program.parse(process.argv);

// Uses
function resolveProjectPaths() {
  // 2. Use nx to find paths to all projects

  // 2.1 Invoke nx from root and make it build the project graph into a output.json
  // Determine the root directory of the Nx workspace
  const workspaceRoot = path.resolve(__dirname, "../../../");
  const nxCommand = "nx graph --file=./tools/mud-merge/projectGraph.json";

  try {
    // Execute the Nx command synchronously
    execSync(nxCommand, { cwd: workspaceRoot });
  } catch (error) {
    console.error(`Error executing Nx command: ${error}`);
  }
  const jsonFilePath: string = path.resolve(
    __dirname,
    "..",
    "projectGraph.json",
  );
  let paths: String[];
  try {
    // Read the JSON file synchronously
    const jsonData: Buffer = fs.readFileSync(jsonFilePath);
    // Parse the JSON data
    const parsedData: any = JSON.parse(jsonData.toString());
    const projects = new Map(Object.entries(parsedData["graph"]["nodes"]));
    paths = Array.from(projects.values()).map((value: any) => {
      return workspaceRoot + "/" + value.data.root;
    });
    return paths;
  } catch (error) {
    console.error("Error reading or parsing JSON file:", error);
  }
  // Get all files that have frontier prefix in their package using nx for querying
  // 3. Copy everything from src into the template src
}

function preMergeClean() {
  // Locate output directory
  // if exists delete it along with all of its contents
}

// check if the option has been used the user
if (options.projects) {
  // const filepath =
  //   typeof options.projects === "string" ? options.projects : __dirname;

  // Pre:
  // 1. Perform cleanup (remove any previous dist folders if present)
  // await preMergeClean();
  // 1. Resolve absolute paths to all monorepo projects
  const projectPaths = resolveProjectPaths();
  console.log("foo");
  console.log(projectPaths);
}
