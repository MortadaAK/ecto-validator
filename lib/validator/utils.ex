defmodule EctoValidator.Validator.Utils do
  alias EctoValidator.Validator.Calculator
  alias Ecto.Changeset

  def resolve_date(:today), do: Date.utc_today()
  def resolve_date(:beginning_of_month), do: Timex.beginning_of_month(Date.utc_today())
  def resolve_date(:beginning_of_quarter), do: Timex.beginning_of_quarter(Date.utc_today())
  def resolve_date(:beginning_of_year), do: Timex.beginning_of_year(Date.utc_today())
  def resolve_date(:beginning_of_week), do: Timex.beginning_of_week(Date.utc_today())
  def resolve_date(:end_of_month), do: Timex.end_of_month(Date.utc_today())
  def resolve_date(:end_of_quarter), do: Timex.end_of_quarter(Date.utc_today())
  def resolve_date(:end_of_year), do: Timex.end_of_year(Date.utc_today())
  def resolve_date(:end_of_week), do: Timex.end_of_week(Date.utc_today())

  def calculate_aggregate_value(changeset, field, field_name, method) do
    case Changeset.get_field(changeset, field) do
      nil ->
        Decimal.new(0)

      table ->
        Enum.reduce(
          table,
          nil,
          &do_calculate_aggregate_value(&1, &2, field_name, method)
        )
    end
  end

  defp do_calculate_aggregate_value(line, agg, field_name, method) do
    case line do
      %Changeset{} -> Changeset.get_field(line, field_name)
      %{} -> Map.get(line, field_name)
      _ -> nil
    end
    |> EctoValidator.Validator.Utils.cast_decimal()
    |> prepare_calculated_aggregate_value(agg, method)
  end

  defp prepare_calculated_aggregate_value(value, nil, _method), do: value
  defp prepare_calculated_aggregate_value(nil, agg, _method), do: agg

  defp prepare_calculated_aggregate_value(value, agg, method),
    do: apply(Decimal, method, [agg, value])

  @doc """
   ths will resolve the operation one by one and whenever it resolve one
  """
  def ensure_variable(changeset, information, field) do
    case {
      Map.has_key?(changeset.changes, field),
      information.operations[field]
    } do
      {_, nil} ->
        changeset

      {true, _} ->
        changeset

      {_, operation} ->
        type = information.types[field]
        {changeset, result} = Calculator.try_to_calculate(changeset, information, operation)

        result =
          case {result, type} do
            {result = %Decimal{}, :integer} ->
              Decimal.round(result, 0)

            _ ->
              result
          end

        changeset
        |> ensure_type(information, field)
        |> Changeset.put_change(field, result)
        |> Changeset.validate_required([field], message: "incorrect operation")
    end
  end

  # this is used when the operation reference is not set
  defp ensure_type(changeset, information, field) do
    %{
      changeset
      | types: Map.put(changeset.types, field, information.types[field])
    }
  end

  def cast_decimal(integer) when is_integer(integer), do: Decimal.new(integer)
  def cast_decimal(float) when is_float(float), do: Decimal.from_float(float)
  def cast_decimal(%Decimal{} = decimal), do: decimal
  def cast_decimal(_), do: nil
  defguardp is_decimal(value) when is_struct(value, Decimal) or is_number(value)

  def gt?(left, right) when is_decimal(left) and is_decimal(right),
    do: Decimal.gt?(cast_decimal(left), cast_decimal(right))

  def gt?(%Date{} = left, %Date{} = right), do: Date.compare(left, right) == :gt
  def gt?(_, _), do: false

  def lt?(left, right) when is_decimal(left) and is_decimal(right),
    do: Decimal.lt?(cast_decimal(left), cast_decimal(right))

  def lt?(%Date{} = left, %Date{} = right), do: Date.compare(left, right) == :lt
  def lt?(_, _), do: false

  def eq?(left, left), do: true

  def eq?(left, right) when is_decimal(left) and is_decimal(right),
    do: Decimal.eq?(cast_decimal(left), cast_decimal(right))

  def eq?(%Date{} = left, %Date{} = right), do: Date.compare(left, right) == :eq
  def eq?(_, _), do: false

  def lteq?(left, right), do: lt?(left, right) or eq?(left, right)
  def gteq?(left, right), do: gt?(left, right) or eq?(left, right)

  def resolve_options(_record, field, {:controlled, {module, function}}) do
    apply(module, function, [field])
  end

  def resolve_options(%module{}, field, {:controlled, function}) do
    apply(module, function, [field])
  end

  def resolve_options(_record, _field, options) do
    options
  end
end
