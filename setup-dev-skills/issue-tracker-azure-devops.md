# Issue Tracker

Provider: Azure DevOps Boards.

Bind organization, project ID, repository ID, and default branch through
`/forge preflight`. Use mounted Azure DevOps Boards/Repos tools first. Work-item
IDs, revisions, comments, relations, and state categories remain provider-native;
shared workflows treat their identifiers and locators as opaque strings.

Positive reviewer votes and `transitionWorkItems` are not normalized to approval
or closure. Verify current blocking policies and the linked work item's observed
Completed state category.

After `/forge preflight`, use `/gitlab-to-issues` to publish an approved plan as vertical work-item slices.
