# Webhooks

Configure outbound API requests inside your pathways using the webhook node.

## Introduction

The webhook node enables outbound API requests to external services during a live call:

- Retrieve data from your backend
- Trigger workflows
- Pass information to third-party systems

## Adding a Webhook Node

1. Open your pathway in the editor
2. Click **New Node**
3. Select the **Webhook** icon

## Node Configuration

### 1. Extract Call Info into Variables

Mirrors variable extraction behavior from default nodes. Based on the conversation up to this point, variables are extracted.

Example extracted variables: `{{user_name}}`, `{{user_interested}}`

### 2. Webhook Configuration

**Request Type:** GET, POST, etc.

**URL:** The endpoint URL. May include query parameters that can interpolate variables:

```
https://api.example.com/users?id={{user_id}}&type={{user_type}}
```

**Authorization:** None, Bearer (token), or Basic (username/password).

**Headers and auth tokens** can reference [Bland Secrets](https://docs.bland.ai/tutorials/secrets).

**Body:** Compose a payload with static values or variables:

```json
{
  "name": "{{user_name}}",
  "interested": "{{user_interested}}",
  "service": "consultation"
}
```

### Built-in Variables

These are automatically available in webhook bodies:

```
{{phone_number}}        — The caller's number
{{timezone}}            — Caller's timezone (e.g., America/New_York)
{{country}}             — Country code (e.g., US)
{{state}}               — State/province abbreviation
{{city}}                — Full city name
{{zip}}                 — Zip code
{{call_id}}             — Unique ID of current call
{{now}}                 — Current time in caller's timezone
{{now_utc}}             — Current time in UTC
{{from}}                — Outbound number (E.164)
{{to}}                  — Inbound number (E.164)
{{short_from}}          — Outbound without country code
{{short_to}}            — Inbound without country code
```

### 3. Advanced Settings

- **Timeout** — Maximum wait time before considering the request failed
- **Retries** — Number of retry attempts on failure
- **Reroute through server** — Helps prevent CORS issues
- **Test API Request** — Send live test request and view response

## Response Data Mapping

If the webhook returns JSON, extract specific values into variables for use in subsequent nodes:

1. Enable **Response Data**
2. For each value to extract:
   - **Variable Name** (e.g., `user_id`)
   - **JSON Path** (e.g., `$.data.id`)
   - **Description** (optional)

## Pathway Routing After Response

Define where to route the agent based on the webhook result:

| Condition | Route To Node |
|----------|---------------|
| API Request Completion (Default) | Default successful node |
| Status code is 200+ | Success node |
| Status code is 500 | Error handling node |

**Important:** The webhook always requires a route for **API Request Completion (Default)** before first save.

**Routing behavior:** Pathways are evaluated from top to bottom. Each condition can overwrite the previous result. The last true condition determines the next node.

If any pathway uses **API Request Completion (Default)**, it overrides all other conditions.

## Speech During Webhook

Enable the agent to speak while the webhook processes — avoids awkward silences during longer API requests.

Example speech: *"One moment while I look up your information."*

## CLI Commands

There are no direct CLI commands for webhook node configuration. Webhooks are configured through the pathway UI.

However, you can test webhooks and inspect their results using call commands:

```bash
bland call get <call_id> --json           # View full call data including webhook calls
bland call events <call_id> --json        # See webhook execution events
```

## Troubleshooting

### Webhook fails with timeout

- Increase the timeout setting in Advanced Settings
- Check if your API is responsive
- Verify the URL is correct and accessible

### CORS issues

- Enable **Reroute through server** in Advanced Settings
- Check if your API supports CORS from Bland's domain
- Use CORS proxy if needed

### Auth errors

- Verify your authorization header is correct
- Check if tokens are stored in Secrets
- Test credentials manually first

### Response variables not captured

- Enable **Response Data** mapping
- Verify JSON Path syntax (use `$.` prefix)
- Test API request to confirm response structure

## Best Practices

1. **Test webhooks** before adding to production pathways
2. **Use Secrets** for API keys and tokens — don't hardcode
3. **Add retries** for unreliable third-party APIs
4. **Set appropriate timeouts** based on expected API response time
5. **Capture response data** when you need to route based on results
6. **Add speech** during long API calls to avoid silence

## Companion Documents

- **[tools.md](tools.md)** — Tools v2 integration
- **[cli-commands.md](cli-commands.md)** — Full CLI reference
- **[custom-code-node.md](custom-code-node.md)** — Custom code节点
- **[workflows/troubleshooting.md](../workflows/troubleshooting.md)** — Debug webhook issues in calls