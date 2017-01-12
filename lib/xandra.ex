defmodule Xandra do
  alias __MODULE__.{Batch, Connection, Error, Prepared, Query, Rows}

  @default_opts [
    host: "127.0.0.1",
    port: 9042,
  ]

  def start_link(opts \\ []) when is_list(opts) do
    opts =
      @default_opts
      |> Keyword.merge(opts)
      |> validate_opts()
      |> Keyword.put(:prepared_cache, Prepared.Cache.new)
    DBConnection.start_link(Connection, opts)
  end

  def stream!(conn, query, params, opts \\ [])

  def stream!(conn, statement, params, opts) when is_binary(statement) do
    with {:ok, query} <- prepare(conn, statement, opts) do
      stream!(conn, query, params, opts)
    end
  end

  def stream!(conn, %Prepared{} = query, params, opts) do
    %Xandra.Stream{conn: conn, query: query, params: params, opts: opts}
  end

  def prepare(conn, statement, opts \\ []) when is_binary(statement) do
    DBConnection.prepare(conn, %Prepared{statement: statement}, opts)
  end

  def prepare!(conn, statement, opts \\ []) do
    case prepare(conn, statement, opts) do
      {:ok, result} -> result
      {:error, exception} -> raise(exception)
    end
  end

  def execute(conn, query, params_or_opts \\ [])

  def execute(conn, statement, params) when is_binary(statement) do
    execute(conn, statement, params, _opts = [])
  end

  def execute(conn, %Prepared{} = prepared, params) do
    execute(conn, prepared, params, _opts = [])
  end

  def execute(conn, %Batch{} = batch, opts) when is_list(opts) do
    with {:ok, %Error{} = error} <- DBConnection.execute(conn, batch, :no_params, opts),
         do: {:error, error}
  end

  def execute(conn, query, params, opts)

  def execute(conn, statement, params, opts) when is_binary(statement) do
    opts = put_paging_state(opts)
    query = %Query{statement: statement}
    with {:ok, %Error{} = error} <- DBConnection.execute(conn, query, params, opts) do
      {:error, error}
    end
  end

  def execute(conn, %Prepared{} = prepared, params, opts) do
    opts = put_paging_state(opts)
    case DBConnection.execute(conn, prepared, params, opts) do
      {:ok, %Error{reason: :unprepared}} ->
        run_prepare_execute(conn, prepared, params, Keyword.put(opts, :force, true))
      {:ok, %Error{} = error} ->
        {:error, error}
      other ->
        other
    end
  end

  def execute!(conn, query, params_or_opts \\ []) do
    case execute(conn, query, params_or_opts) do
      {:ok, result} -> result
      {:error, exception} -> raise(exception)
    end
  end

  def execute!(conn, query, params, opts) do
    case execute(conn, query, params, opts) do
      {:ok, result} -> result
      {:error, exception} -> raise(exception)
    end
  end

  def prepare_execute(conn, statement, params, opts \\ []) when is_binary(statement) do
    prepared = %Prepared{statement: statement}
    with {:error, %Error{reason: :unprepared}} <- run_prepare_execute(conn, prepared, params, opts) do
      run_prepare_execute(conn, prepared, params, Keyword.put(opts, :force, true))
    end
  end

  defp run_prepare_execute(conn, %Prepared{} = prepared, params, opts) do
    with {:ok, _prepared, %Error{} = error} <- DBConnection.prepare_execute(conn, prepared, params, opts) do
      {:error, error}
    end
  end

  def prepare_execute!(conn, statement, params, opts \\ []) do
    case prepare_execute(conn, statement, params, opts) do
      {:ok, prepared, result} -> {prepared, result}
      {:error, exception} -> raise(exception)
    end
  end

  defp put_paging_state(opts) do
    case Keyword.pop(opts, :cursor) do
      {%Rows{paging_state: paging_state}, opts} ->
        Keyword.put(opts, :paging_state, paging_state)
      {nil, opts} ->
        opts
    end
  end

  defp validate_opts(opts) do
    Enum.map(opts, fn
      {:host, host} ->
        if is_binary(host) do
          {:host, String.to_charlist(host)}
        else
          raise ArgumentError, "expected a string as the value of the :host option, got: #{inspect(host)}"
        end
      {:port, port} ->
        if is_integer(port) do
          {:port, port}
        else
          raise ArgumentError, "expected an integer as the value of the :port option, got: #{inspect(port)}"
        end
      {_key, _value} = option ->
        option
    end)
  end
end
