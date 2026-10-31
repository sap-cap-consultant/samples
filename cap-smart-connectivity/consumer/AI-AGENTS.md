# consumer for AI agents: the same services over MCP

The consumer integrates four backends (OData V4, OData V2, SOAP) and its own database into one CDS model, with
[`cap-smart-connectivity`](https://www.npmjs.com/package/cap-smart-connectivity). The same model is served to AI
agents through the [Model Context Protocol](https://modelcontextprotocol.io) by SAP's CAP plugin
[`@cap-js/mcp`](https://cap.cloud.sap/docs/guides/protocols/mcp): no tool code, no second integration.

```diagram
AI agent (Claude Code, VS Code, Joule, ...)        Fiori / any OData client
          │ MCP: describe · query · call                  │ OData V4
          ▼                                               ▼
   /mcp/catalog, /mcp/restricted           /odata/v4/catalog, /odata/v4/restricted
          └────────────── same CAP services ──────────────┘
                  remote.ApplicationService (cap-smart-connectivity)
                  push-down, mapping, key reads, joins, @restrict
          │ OData V4          │ OData V2           │ OData V4          │ SOAP
          ▼                   ▼                    ▼                   ▼
   producer-customers   producer-products    producer-sales     producer-partners
```

---

## 📑 Table of Contents

🧩 [What is added](#-what-is-added)\
▶️ [Running it](#️-running-it)\
🤖 [Connecting an agent](#-connecting-an-agent)\
🔗 [Downstream: one question, three systems](#-downstream-one-question-three-systems)\
🔒 [Upstream: the agent is the user](#-upstream-the-agent-is-the-user)\
✏️ [Changes through actions](#️-changes-through-actions)\
🚧 [Limits](#-limits)

---

## 🧩 What is added

| File | Purpose |
| --- | --- |
| [srv/mcp.cds](srv/mcp.cds) | `@odata @mcp` on CatalogService and RestrictedService, with `@mcp.instructions` (what the agent is told about the systems and codes) |
| [package.json](package.json) | the dependency `@cap-js/mcp`; `cds.mcp.prefix` (tool names `CatalogService-query`, ...), `cds.mcp.autowire` (the mocked user of the local agent) |
| [test/http/MCP.http](test/http/MCP.http) | the requests of this page as raw MCP calls (VS Code REST Client) |

`@mcp` is a protocol annotation like `@odata`; a service that names protocols is served by those only, so both are
named and every OData endpoint and `test/http` request stays as it is. Each MCP endpoint serves three tools:

| Tool | What it does | Hint to the client |
| --- | --- | --- |
| `<Service>-describe` | entities, elements, keys, associations, query limits; the doc comments of the `.cds` files become descriptions | read only |
| `<Service>-query` | one CQL `SELECT` (paths through associations, nested expands, aggregates), run as a query of the service | read only |
| `<Service>-call` | an unbound action or function of the service | destructive: the client asks the user |

---

## ▶️ Running it

Start the four producers and the consumer as described in [../README.md](../README.md). The consumer's boot log lists
both endpoints of each service:

```text
[cds] - serving CatalogService {
  at: [ '/odata/v4/catalog', '/mcp/catalog' ],
[cds] - serving RestrictedService {
  at: [ '/odata/v4/restricted', '/mcp/restricted' ],
```

---

## 🤖 Connecting an agent

**Claude Code, OpenCode: automatic.** Under `cds watch` (profile `development`) the plugin registers every MCP
endpoint with the local agents when the server starts, and removes them when it stops: entries `cds:CatalogService`
and `cds:RestrictedService` in `~/.claude.json` (`mcpServers`) and, if it exists, `~/.config/opencode/opencode.json`.
They carry a basic-authentication header of `cds.mcp.autowire` (here the mocked user `alice`). A server that is
killed (not stopped) leaves its entries behind; the next start overwrites them. Set `"autowire": false` under
`cds.mcp` to turn it off.

**Any other client, or another user:** register the endpoint yourself, e.g. for Claude Code as `bob`:

```bash
claude mcp add --transport http catalog-bob http://localhost:5005/mcp/restricted --header "Authorization: Basic Ym9iOmJvYg=="
```

(`Ym9iOmJvYg==` is `bob:bob` in Base64.) Then ask the agent in plain language; it calls `describe` first and writes
the CQL itself.

---

## 🔗 Downstream: one question, three systems

> Which open orders above 100 have the highest amounts, for which customers and regions, and with which products?

The agent sends one `query`:

```sql
SELECT from Orders { ID, Title, Status, CustomerName, CustomerRegion, _Items { ProductName, Quantity } }
 where Status = 'O' and Amount > 100 order by Amount desc limit 3
```

and the consumer log shows what reached the backends: the filter, order and limit are pushed to the sales system,
everything else is read by key.

```text
[mcp] - CatalogService query
[remote] - GET http://localhost:7007/odata/v4/sales/Orders?$select=ID,OrderName,Status,Customer&$filter=Status eq 'O' and Amount gt 100&$top=3&$count=true&$orderby=Amount desc,ID asc
[remote] - GET http://localhost:9009/odata/v4/customer/Customers?$select=Name,GroupID,ID&$filter=(ID eq 'C004' or ID eq 'C007' or ID eq 'C001')
[remote] - GET http://localhost:9009/odata/v4/customer/CustomerGroups?$select=Region,ID&$filter=(ID eq 'G300' or ID eq 'G200' or ID eq 'G100')
[remote] - GET http://localhost:7007/odata/v4/sales/Items?$select=Quantity,OrderID,Product,ID&$filter=(OrderID eq 'O006' or OrderID eq 'O009' or OrderID eq 'O001')&...
[remote] - GET http://localhost:8008/odata/v2/product/Products?$select=Name,ID&$filter=(ID eq 'P004' or ID eq 'P001' or ...)
```

The answer names local fields only (`Title`, `CustomerName`, `CustomerRegion`, `ProductName`): the agent never sees
the backends' names, URLs or credentials. The join view `PartnerCustomers` does the same for the SOAP partner
directory and the customer system (one SOAP call, one read by key).

---

## 🔒 Upstream: the agent is the user

The agent calls with the identity of its connection, and CAP checks `@requires` / `@restrict` as for any OData
request. The same `query` on RestrictedService:

| User | Rows | Sent to producer-customers |
| --- | --- | --- |
| `alice` (admin) | 8 | `$select=ID,Name,CompanyCode&$top=1000&$orderby=ID` |
| `bob` (CompanyCode 1000) | 4 | `... &$filter=(CompanyCode eq '1000')` |
| `kim` (CompanyCode 2000) | 2 | `... &$filter=(CompanyCode eq '2000')` |
| `sam` (no CompanyCode) | 0 | nothing: no backend call |
| wrong password | HTTP 401 | nothing |

Entities and actions a user may not read or call are left out of that user's `describe` and tools.

---

## ✏️ Changes through actions

The MCP tools read and call unbound actions; they do not create, update or delete rows. CatalogService has one unbound
action, `setCustomerStatus`, forwarded to `CustomerService.setStatus` of producer-customers. The `call` tool is
marked destructive, so the agent asks before it runs, and `@mcp.instructions` tells it to wait for the user's
confirmation:

```json
{ "action": "setCustomerStatus", "parameters": { "ID": "C006", "Status": "B" } }
```

A following `query` of `Customers` shows `Status: B`, `IsBlocked: true`. [test/http/MCP.http](test/http/MCP.http)
sets it back.

---

## 🚧 Limits

- Bound actions and functions (`Customers.block`, `creditCheck`) and CREATE / UPDATE / DELETE are not served over
  MCP; expose a change as an unbound action.
- The tools are meant for agents and are not a stable API; programs use OData.
- `@cap-js/mcp` does not filter what the backends return: data can contain text that tries to steer an agent.
  Connect trusted agents only, and keep a human confirmation on every `call`.
- Every MCP query is a query of the service: `@cds.query.limit` (here 1000 / 5000) and the
  `cds.query.remote` limits apply as for OData.
- The SAP API Policy applies to SAP data served through MCP, as through any other protocol.
