# Custom Code Node

> Execute custom JavaScript code within conversational pathways.

## Overview

The Custom Code Node runs JavaScript within conversations for advanced data processing, calculations, API calls, and business logic — securely on Bland's infrastructure, with fast performance and no need for outside services.

**Prerequisites:**
- Bland Enterprise account with Custom Code Node access (contact Bland support)
- Basic knowledge of JavaScript programming
- Understanding of JSON data structures

## Call Flow

1. Agent enters custom code node during pathway execution
2. Variables from conversation are extracted and available to your code
3. Custom JavaScript code executes with access to these variables
4. Code returns JSON response
5. Returned data becomes available as variables in subsequent nodes
6. Agent continues to next node

## Node Configuration

### Reference Variables

Two types of variables can be used in custom code:

**Static Variables:** Constants that are the same for all calls, defined in this section.

**Dynamic Variables:** Defined based on variables extracted previously in the pathway.

Example extraction code (auto-generated):

```javascript
const age = json["user_age"]
const county = json["county"]
```

### Code Editor

Provides:
- Syntax highlighting for JavaScript
- Auto-completion and IntelliSense
- Error detection and debugging
- Code formatting

### Test Mode

Toggle between normal editing and test mode:

- **Normal Mode:** Configure actual variables extracted from conversations
- **Test Mode:** Set mock values for testing, use **Run Test** to see results

### Response Handling

Code must return JSON using `Response.json()`:

```javascript
return Response.json({
  processed_total: calculatedAmount,
  discount_applied: discountPercentage,
  final_price: finalAmount,
  customer_tier: tierLevel
});
```

Returned values become available in subsequent nodes using `{{processed_total}}`, `{{discount_applied}}`, etc.

## Example Logic

```javascript
export default {
  async fetch(request, env, ctx) {
    const json = await request.json();

    const age = json["user_age"]
    const county = json["county"]

    if (age > 25){
      return Response.json({
        "qualified": true,
        "county": county
      })
    } else {
      return Response.json({
        "qualified": false,
        "county": county
      })
    }
  }
}
```

In this example, callers under 25 are automatically rejected.

## CLI Commands

```bash
bland pathway code test <pathway_id> <node_id>         # Test a custom code node
bland pathway code test <pathway_id> <node_id> --input '{"key":"value"}'
```

## Best Practices

1. **Test in Test Mode** — Verify logic with mock data before live calls
2. **Use clear variable names** — Make code readable and maintainable
3. **Handle errors** — Include try/catch for robust error handling
4. **Validate input** — Check that required variables exist before using them
5. **Return clear structure** — Use consistent JSON schema in responses

## Security

- Code runs in secure isolate on Bland's infrastructure
- No direct access to external services unless you make HTTP requests
- Do not hardcode API keys — use Bland Secrets
- Validate all inputs before processing

## Use Cases

- **Complex calculations** — Age verification, pricing logic
- **Data transformation** — Convert data formats, merge information
- **API calls to external services** — Fetch data from your backend
- **Business logic** — Implement custom routing or decision logic
- **Data validation** — Verify extracted information before use

## Full API

See full documentation at https://docs.bland.ai/enterprise-features/custom-code-node.md

## Companion Documents

- **[cli-commands.md](cli-commands.md)** — Full CLI reference
- **[tools.md](tools.md)** — Tools integration
- **[webhooks.md](webhooks.md)** — Webhook node configuration
- **[workflows/troubleshooting.md](../workflows/troubleshooting.md)** — Debug custom code nodes