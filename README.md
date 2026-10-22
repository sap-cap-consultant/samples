# Samples

Runnable SAP CAP landscapes for two npm packages:

| Folder | Package | What it shows |
| --- | --- | --- |
| [cap-soap-connectivity](cap-soap-connectivity/README.md) | [`cap-soap-connectivity`](https://www.npmjs.com/package/cap-soap-connectivity) | SOAP web services exposed as OData-style entities and used in-process from a CAP service |
| [cap-smart-connectivity](cap-smart-connectivity/README.md) | [`cap-smart-connectivity`](https://www.npmjs.com/package/cap-smart-connectivity) | CDS projections served over remote OData V2 / V4, SOAP and local data, without handler code |

Each folder has its own README with the start order of the producers and the consumer, and `test/http/*.http` files
with ready-made requests.

```bash
git clone https://github.com/sap-cap-consultant/samples.git
cd samples/cap-soap-connectivity/producer-catalog && npm install && npm run watch
```

Requirements: Node.js 22 or later; `@sap/cds-dk` (`npm i -g @sap/cds-dk`) for `cds watch`.
