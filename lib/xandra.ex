defmodule Xandra do
  alias __MODULE__.{Connection, Prepared, Query, Error}

  @default_opts [
    host: "127.0.0.1",
    port: 9042,
  ]

  def start_link(opts \\ []) when is_list(opts) do
    opts =
      @default_opts
      |> Keyword.merge(opts)
      |> validate_opts()
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

  def execute(conn, statement, params, opts \\ [])

  def execute(conn, statement, params, opts) when is_binary(statement) do
    execute(conn, %Query{statement: statement}, params, opts)
  end

  def execute(conn, %kind{} = query, params, opts) when kind in [Query, Prepared] do
    with {:ok, %Error{} = error} <- DBConnection.execute(conn, query, params, opts) do
      {:error, error}
    end
  end

  def prepare_execute(conn, statement, params, opts \\ []) when is_binary(statement) do
    DBConnection.prepare_execute(conn, %Prepared{statement: statement}, params, opts)
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
    end)
  end
end
