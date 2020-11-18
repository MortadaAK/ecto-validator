defmodule EctoValidator do
  alias __MODULE__.{Parser, Validator, Validator.Initializer}

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import EctoValidator
    end
  end

  defmacro schema_with_validations(table_name, do: block) do
    groups =
      block
      |> Parser.parse_groups(__CALLER__)

    rebuild_ast(table_name, groups)
  end

  defp rebuild_ast(table_name, groups) do
    block =
      groups
      |> Enum.flat_map(& &1.fields)
      |> Enum.map(fn field ->
        {
          field.deftype,
          field.info,
          [field.name, field.field_type, field.options]
        }
      end)

    groups = groups |> Initializer.build_types() |> Macro.escape()

    quote do
      @information unquote(groups)
      schema(unquote(table_name), do: {:__block__, [], unquote(block)})
      def __information__(), do: @information
    end
  end

  def changeset(%schema{} = record, params \\ %{}) do
    information = apply(schema, :__information__, [])
    __MODULE__.Validator.changeset(information, record, params)
  end
end
