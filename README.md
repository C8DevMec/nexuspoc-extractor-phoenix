# Nexuspoc Extractor

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Configuration

Before running the application, you must configure the path to the PowerShell data-fetching script. Add the following line to your `config/config.exs` (or environment-specific config like `config/runtime.exs`):

```elixir
# in config/config.exs or runtime.exs
config :nexuspoc_extractor,
  nexus_script_path: "C:/path/to/your/Get-PIData.ps1"
```

## API Endpoints

The API exposes two primary endpoints

### 1. API Discovery

Provides a simple message indicating the accepted parameters for the main endpoint

- **Endpoint:** `/api`
- **Method:** `GET`
- **Request Body:** None

**Success Response (200 OK)**

```json
{
  "message": "Accepted parameters: tagnames, starttime, endtime"
}
```

### 2. Fetch PI Data

The main endpoint for data extraction. It operates in two modes (snapshot or archive) based on the parameters provided in JSON body.

- **Endpoint:** `/api/extract`
- **Method:** `POST`
- **Content-Type:** `application/json`

### Mode 1: Snapshot

To fetch the latest recorded value for one or more tags, provide only the `tagnames key.

**Request Body**

```json
{
  "tagnames": ["sinusoid", "cdt158"]
}
```

**Success Response (200 OK)**

```json
{
  "data": [
    {
      "TagName": "sinusoid",
      "Value": 50.001,
      "Timestamp": "2023-10-27T15:30:00.0000000Z",
      "IsGood": true
    },
    {
      "TagName": "cdt158",
      "Value": 157.98,
      "Timestamp": "2023-10-27T15:29:55.0000000Z",
      "IsGood": true
    }
  ]
}
```

### Mode 2: Archived

To fetch historical data within a time range, provide `tagnames`, `starttime`, and `endtime`

**Request Body**

```json
{
  "tagnames": ["sinusoid"],
  "starttime": "*-1h",
  "endtime": "*"
}
```

*Note: `starttime` and `endtime` can be any valid PI time string*

**Success Response (200 OK)**

```json
{
  "data": [
    {
      "TagName": "sinusoid",
      "Value": 85.9167,
      "Timestamp": "2023-10-27T10:00:03.0000000Z",
      "IsGood": true
    },
    {
      "TagName": "sinusoid",
      "Value": 84.51441,
      "Timestamp": "2023-10-27T10:00:13.0000000Z",
      "IsGood": true
    }
    // ... more data points
  ]
}
```

## Error Handling

### Invalid Request Parameters

If the request body does not match one of the two valid formats (either just `tagnames` or all three of `tagnames`, `starttime`, and `endtime`), the API will respond with a `400 Bad Request`.


**Response Body (400 Bad Request)**

```json
{
  "error": "Invalid parameters. Provide either 'tagnames' alone for snapshot or 'tagnames', 'starttime', and 'endtime' for archive data"
}
```

### PowerShell Execution Failure

If the underlying PowerShell script fails to execute correctly (e.g., cannot connect to the PI server, tag not found, AF SDK not installed), the API will still return a `200 OK` status but with an error message in the body. More detailed error information from the script will be printed to the Elixir application's server console logs.

**Response (200 OK)**

```json
{
  "error": "Failed to retrieve PI data."
}
```