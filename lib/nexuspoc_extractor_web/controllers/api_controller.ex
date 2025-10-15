defmodule NexuspocExtractorWeb.ApiController do
  use NexuspocExtractorWeb, :controller

  def index(conn, _params) do
    json(conn, %{
      message: "Accepted parameters: tagnames, starttime, endtime"
    })
  end

  def create(conn, %{"tagnames" => tagnames} = params)
      when not is_map_key(params, "starttime") and not is_map_key(params, "endtime") do
    case get_snapshot(tagnames) do
      {:ok, data} -> json(conn, %{data: data})
      {:error, reason} -> json(conn, %{error: reason})
    end
  end

  def create(conn, %{"tagnames" => tagnames, "starttime" => starttime, "endtime" => endtime}) do
    case get_archive_data(tagnames, starttime, endtime) do
      {:ok, data} -> json(conn, %{data: data})
      {:error, reason} -> json(conn, %{error: reason})
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

    case System.cmd("powershell.exe", ps_args, stderr_to_stdout: true) do
      {output, 0} ->
        Jason.decode(output)

      {output, exit_code} ->
        IO.puts("PowerShell script failed with exit code #{exit_code}: #{output}")
        {:error, "Failed to retrieve PI data."}
    end
  end

  defp get_script_path, do: Application.fetch_env!(:nexuspoc_extractor, :nexus_script_path)
end
