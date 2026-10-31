/**
 * MCP: the services of this consumer, served to AI agents as well (plugin @cap-js/mcp, see AI-AGENTS.md).
 *
 * `@mcp` is a protocol annotation like `@odata`: a service that names one protocol is served by that protocol only,
 * so `@odata` is named too and every OData endpoint and test/http request stays as it is. Each MCP endpoint
 * (/mcp/catalog, /mcp/restricted) serves the tools `describe`, `query` and `call`; every request runs through the
 * same service implementation (remote.ApplicationService) as an OData request, with the same push-down to the
 * backends and the same `@requires` / `@restrict` checks for the calling user.
 */
using from './catalog-service';
using from './restricted-service';

annotate CatalogService with @odata @mcp @mcp.instructions: 'One model over four systems and a local database. Customers, CustomerGroups, Contacts: customer system (OData V4). Products, Categories: product system (OData V2). Orders, Items: sales system (OData V4). Partners: partner directory (SOAP). Regions: local database. Orders.CustomerName, Orders.CustomerRegion and Items.ProductName read across systems; OrderLines, PartnerCustomers and GroupRegions are join views over several systems. Order Status: O open, X closed, C cancelled. Customer Status: A active, B blocked. Use describe before the first query, select only the columns you need and keep a limit. setCustomerStatus changes a customer in the customer system: call it only after the user confirmed the change.';

annotate RestrictedService with @odata @mcp @mcp.instructions: 'Customers and Orders as the calling user may see them: a user without the admin role sees only the customers of the own CompanyCode.';
