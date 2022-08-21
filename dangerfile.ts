import { danger } from "danger";

const CHANGESET_REGEX_CHECK = /^(.changeset)(\/\w+)/;
const NO_CHANGESET_LABEL = "approved-no-changeset";

const containsChangeset = danger.git.created_files.some((file) => CHANGESET_REGEX_CHECK.test(file));

if (!containsChangeset) {
    const noChangesetNeeded = danger.github.issue.labels.some((label) => label.name === NO_CHANGESET_LABEL);
    if (!noChangesetNeeded) {
        fail("This PR does not contain a changeset. Please add one.");
    }
}
