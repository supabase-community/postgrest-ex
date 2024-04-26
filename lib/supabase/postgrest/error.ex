defmodule Supabase.PostgREST.Error do
  @derive Jason.Encoder
  defstruct [:hint, :details, :code, :message]

  @type t :: %__MODULE__{
          hint: String.t() | nil,
          details: String.t() | nil,
          code: String.t() | nil,
          message: String.t()
        }

  def from_raw_body(%{message: message} = err) do
    %__MODULE__{
      message: message,
      hint: err[:hint],
      details: err[:details],
      code: err[:code]
    }
  end
end
