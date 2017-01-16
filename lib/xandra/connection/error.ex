defmodule Xandra.Connection.Error do
  @moduledoc """
  An exception struct that represents an error in the connection to the
  Cassandra server.

  For more information on when this error is returned or raised, see the
  documentation for the `Xandra` module.

  The `:action` field represents the action that was being performed when the
  connection error occurred. The `:reason` field represents the reason of the
  connection error: for network errors, this is usually a POSIX reason (like
  `:econnrefused`).

  Since this struct is an exception, it is possible to raise it with
  `Kernel.raise/1`. If the intent is to format connection errors as strings (for
  example, for logging purposes), it is possible to use `Exception.message/1` to
  get a formatted version of the error.
  """
  defexception [:action, :reason]

  @type t :: %__MODULE__{
    action: String.t,
    reason: atom,
  }

  @spec new(String.t, atom) :: t
  def new(action, reason) when is_binary(action) and is_atom(reason) do
    %__MODULE__{action: action, reason: reason}
  end

  def message(%__MODULE__{} = exception) do
    "on action \"#{exception.action}\": #{format_reason(exception.reason)}"
  end

  defp format_reason(reason) do
    case :inet.format_error(reason) do
      'unknown POSIX error' -> inspect(reason)
      formatted -> List.to_string(formatted)
    end
  end
end
