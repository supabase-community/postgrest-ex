defmodule Supabase.PostgREST.Error do
  @derive Jason.Encoder
  defstruct [:hint, :details, :code, :message]

  def from_raw_body(%{message: message} = err) do
    %__MODULE__{
      message: message,
      hint: err[:hint],
      details: err[:details],
      code: err[:code]
    }
  end
end
