using { CatalogService as catalog } from './catalog-service';

/**
 * A curated service for AI agents next to the services of the apps, on the same process (see AI-AGENTS.md).
 *
 * `@remote.budget` and `@remote.maskBackendErrors` apply to the requests a client sends to this service only; the
 * apps reading CatalogService keep the settings of package.json (`cds.query.remote`). The budget is resolved per
 * limit: the entity's annotation, then the service's, then `cds.query.remote.budget`. The layer below
 * (CatalogService, and the systems behind it) counts against the budget of this service, and an over-budget request
 * is a 502 REMOTE_BUDGET_EXCEEDED that names the annotation. With `cds.query.remote.agentHints` the budget is part of
 * what `describe` shows.
 */
@remote
@remote.budget: { requests: 6, rows: 40, seconds: 30 }
@remote.maskBackendErrors
service AgentService {

    /** The orders with the name of their customer (two systems). */
    @readonly
    entity Orders    as projection on catalog.Orders {
        key ID,
            Title,
            Status,
            Amount,
            Currency,
            CustomerName
    };

    /** A tighter budget for one entity: at most 5 rows answered by the backends for a request to it. */
    @readonly
    @remote.budget.rows: 5
    entity Customers as projection on catalog.Customers {
        key ID,
            CustomerName,
            Status,
            City
    };

    /** Forwarded to CatalogService (and from there to the customer system); a refusal of the backend is masked here. */
    @remote.operation: 'CatalogService.setCustomerStatus'
    @remote.cache.invalidates: [Customers]
    action setCustomerStatus(ID : String(10), Status : String(1)) returns Customers;
}

annotate AgentService with @odata @mcp @mcp.instructions: 'Orders and customers for agents, read from the sales and the customer system. Order Status: O open, X closed, C cancelled. Customer Status: A active, B blocked. A request has a budget (see describe): select only the columns you need and keep a limit. setCustomerStatus changes a customer in the customer system: call it only after the user confirmed the change.';
