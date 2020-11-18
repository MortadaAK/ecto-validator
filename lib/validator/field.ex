defmodule EctoValidator.Field do
  @moduledoc false
  defstruct [
    :name,
    :operation,
    :type,
    :deftype,
    :validations,
    :options,
    :foreign_key,
    :unique?,
    :default,
    :filters,
    :cast?,
    controlled?: false
  ]
end
