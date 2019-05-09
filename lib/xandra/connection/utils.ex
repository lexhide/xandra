defmodule Xandra.Connection.Utils do
  @moduledoc false

  alias Xandra.{ConnectionError, Frame, Protocol}

  @spec recv_frame(:gen_tcp | :ssl, term, nil | module) ::
          {:ok, Frame.t()} | {:error, :closed | :inet.posix()}
  def recv_frame(transport, socket, compressor \\ nil) when is_atom(compressor) do
    length = Frame.header_length()

    with {:ok, header} <- transport.recv(socket, length) do
      case Frame.body_length(header) do
        0 ->
          {:ok, Frame.decode(header)}

        body_length ->
          with {:ok, body} <- transport.recv(socket, body_length),
               do: {:ok, Frame.decode(header, body, compressor)}
      end
    end
  end

  @spec request_options(:gen_tcp | :ssl, term, nil | module) ::
          {:ok, term} | {:error, ConnectionError.t()}
  def request_options(transport, socket, compressor \\ nil) do
    payload =
      Frame.new(:options)
      |> Protocol.encode_request(nil)
      |> Frame.encode()

    with :ok <- transport.send(socket, payload),
         {:ok, %Frame{} = frame} <- recv_frame(transport, socket, compressor) do
      {:ok, Protocol.decode_response(frame)}
    else
      {:error, reason} ->
        {:error, ConnectionError.new("request options", reason)}
    end
  end

  @spec startup_connection(:gen_tcp | :ssl, term, map, nil | module) ::
          :ok | {:error, ConnectionError.t()}
  def startup_connection(transport, socket, requested_options, compressor \\ nil, options \\ [])
      when is_map(requested_options) and is_atom(compressor) do
    # We have to encode the STARTUP frame without compression as in this frame
    # we tell the server which compression algorithm we want to use.
    payload =
      Frame.new(:startup)
      |> Protocol.encode_request(requested_options)
      |> Frame.encode()

    # However, we need to pass the compressor module around when we
    # receive the response to this frame because if we said we want to use
    # compression, this response is already compressed.
    with :ok <- transport.send(socket, payload),
         {:ok, frame} <- recv_frame(transport, socket, compressor) do
      case frame do
        %Frame{body: <<>>} ->
          :ok

        %Frame{kind: :authenticate} ->
          authenticate_connection(transport, socket, requested_options, compressor, options)

        _ ->
          raise "protocol violation, got unexpected frame: #{inspect(frame)}"
      end
    else
      {:error, reason} ->
        {:error, ConnectionError.new("startup connection", reason)}
    end
  end

  defp authenticate_connection(transport, socket, requested_options, compressor, options) do
    payload =
      Frame.new(:auth_response)
      |> Protocol.encode_request(requested_options, options)
      |> Frame.encode()

    with :ok <- transport.send(socket, payload),
         {:ok, frame} <- recv_frame(transport, socket, compressor) do
      case frame do
        %Frame{kind: :auth_success} -> :ok
        %Frame{kind: :error} -> {:error, Protocol.decode_response(frame)}
        _ -> raise "protocol violation, got unexpected frame: #{inspect(frame)}"
      end
    else
      {:error, reason} ->
        {:error, ConnectionError.new("authenticate connection", reason)}
    end
  end
end
