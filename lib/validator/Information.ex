defmodule EctoValidator.Information do
  @moduledoc false
  defstruct types: %{},
            validations: %{},
            operations: %{},
            defaults: %{},
            assocs: %{},
            fields_to_casts: [],
            assocs_to_cast: [],
            groups: [],
            dependencies: %{}

  @type t :: %__MODULE__{}
end
