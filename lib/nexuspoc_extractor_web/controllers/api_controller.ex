defmodule NexuspocExtractorWeb.ApiController do
  use NexuspocExtractorWeb, :controller
  require Logger

  def index(conn, _params) do
    json(conn, %{
      message: "Accepted parameters: tagnames (hierarchical structure), starttime, endtime"
    })
  end

  def create(conn, %{"tagnames" => tagnames} = params)
      when not is_map_key(params, "starttime") and not is_map_key(params, "endtime") do
    Logger.info("Snapshot request received")

    with {:ok, flat_tags, structure} <- extract_tag_structure(tagnames),
         {:ok, data} <- get_snapshot(flat_tags) do
      Logger.info("Flat tags: #{inspect(flat_tags)}")
      Logger.info("Structure: #{inspect(structure)}")
      Logger.info("Raw data from PowerShell: #{inspect(data)}")

      restructured_data = restructure_response(data, structure)
      Logger.info("Restructured data: #{inspect(restructured_data)}")

      json(conn, %{data: restructured_data})
    else
      {:error, reason} ->
        Logger.error("Error in snapshot request: #{inspect(reason)}")
        json(conn, %{error: reason})
    end
  end

  def create(conn, %{"tagnames" => tagnames, "starttime" => starttime, "endtime" => endtime}) do
    Logger.info("Archive request received - Start: #{starttime}, End: #{endtime}")

    with {:ok, flat_tags, structure} <- extract_tag_structure(tagnames),
         {:ok, data} <- get_archive_data(flat_tags, starttime, endtime) do
      Logger.info("Flat tags: #{inspect(flat_tags)}")
      Logger.info("Structure: #{inspect(structure)}")

      Logger.info(
        "Raw data from PowerShell (#{length(data)} records): #{inspect(Enum.take(data, 5))}"
      )

      restructured_data = restructure_response(data, structure)
      Logger.info("Restructured data summary: #{inspect(Map.keys(restructured_data))}")

      json(conn, %{data: restructured_data})
    else
      {:error, reason} ->
        Logger.error("Error in archive request: #{inspect(reason)}")
        json(conn, %{error: reason})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error:
        "Invalid parameters. Provide either 'tagnames' alone for snapshot or 'tagnames', 'starttime', and 'endtime' for archive data"
    })
  end

  defp extract_tag_structure(tagnames) when is_map(tagnames) do
    {flat_tags, structure} = flatten_tags(tagnames, [])
    {:ok, flat_tags, structure}
  end

  defp extract_tag_structure(_tagnames) do
    {:error, "tagnames must be a hierarchical map structure"}
  end

  defp flatten_tags(map, path) when is_map(map) do
    Enum.reduce(map, {[], %{}}, fn {key, value}, {tags_acc, structure_acc} ->
      new_path = path ++ [key]
      {child_tags, child_structure} = flatten_tags(value, new_path)

      {tags_acc ++ child_tags, Map.put(structure_acc, key, child_structure)}
    end)
  end

  defp flatten_tags(list, path) when is_list(list) do
    tag_map =
      Enum.reduce(list, %{}, fn tag, acc ->
        Map.put(acc, tag, path)
      end)

    {list, tag_map}
  end

  defp flatten_tags(value, path) do
    {[value], %{value => path}}
  end

  defp restructure_response(data, structure) when is_list(data) do
    Logger.debug("Restructuring response with structure: #{inspect(structure)}")
    Logger.debug("Data count: #{length(data)}")

    # Group data by tags
    data_by_tag =
      Enum.group_by(data, fn item ->
        Map.get(item, "TagName") || Map.get(item, :TagName)
      end)

    Logger.debug("Data grouped by tag: #{inspect(Map.keys(data_by_tag))}")

    rebuild_structure(structure, data_by_tag)
  end

  defp rebuild_structure(structure, data_by_tag) when is_map(structure) do
    Logger.debug("Rebuilding structure level: #{inspect(Map.keys(structure))}")

    # Check if this is a leaf level (contains tag mappings)
    # A leaf level map has string keys (tag names) and list values (paths)
    is_leaf_level =
      structure
      |> Map.values()
      |> Enum.all?(fn value -> is_list(value) end)

    if is_leaf_level do
      # This is the leaf level - extract tags and their data
      Logger.debug("Detected leaf level with tags: #{inspect(Map.keys(structure))}")

      tags = Map.keys(structure)

      data =
        Enum.flat_map(tags, fn tag ->
          case Map.get(data_by_tag, tag) do
            nil ->
              Logger.warning("No data found for tag: #{tag}")
              []

            tag_data ->
              Logger.debug("Found #{length(tag_data)} records for tag: #{tag}")
              tag_data
          end
        end)

      Logger.debug("Collected #{length(data)} total records at this level")
      data
    else
      # This is an intermediate level - recurse
      Enum.reduce(structure, %{}, fn {key, value}, acc ->
        Map.put(acc, key, rebuild_structure(value, data_by_tag))
      end)
    end
  end

  defp rebuild_structure(_other, _data_by_tag) do
    Logger.debug("Rebuild structure catch-all: #{inspect(_other)}")
    []
  end

  defp get_snapshot(tagnames) when is_list(tagnames) do
    tag_string = Enum.join(tagnames, ",")
    args = ["-File", get_script_path(), "-TagNames", tag_string]
    execute_powershell(args)
  end

  defp get_archive_data(tagnames, start_time, end_time) when is_list(tagnames) do
    tag_string = Enum.join(tagnames, ",")

    args = [
      "-File",
      get_script_path(),
      "-TagNames",
      tag_string,
      "-StartTime",
      start_time,
      "-EndTime",
      end_time
    ]

    execute_powershell(args)
  end

  defp execute_powershell(args) do
    ps_args = ["-NonInteractive", "-ExecutionPolicy", "Bypass" | args]

    Logger.info("Executing PowerShell with args: #{inspect(ps_args)}")

    case System.cmd("powershell.exe", ps_args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("PowerShell output: #{String.slice(output, 0, 500)}")

        case Jason.decode(output) do
          {:ok, data} ->
            Logger.info("Successfully decoded #{length(data)} records")
            {:ok, data}

          {:error, decode_error} ->
            Logger.error("JSON decode error: #{inspect(decode_error)}")
            Logger.error("Raw output: #{output}")
            {:error, "Failed to decode PowerShell output"}
        end

      {output, exit_code} ->
        Logger.error("PowerShell script failed with exit code #{exit_code}")
        Logger.error("PowerShell output: #{output}")
        {:error, "Failed to retrieve PI data. Exit code: #{exit_code}"}
    end
  end

  defp get_script_path, do: Application.fetch_env!(:nexuspoc_extractor, :nexus_script_path)
end
