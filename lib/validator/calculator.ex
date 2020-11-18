defmodule EctoValidator.Validator.Calculator do
  alias Ecto.Changeset
  alias EctoValidator.Validator.{Utils, Checker}
  require Logger

  @date_types [
    :today,
    :beginning_of_month,
    :beginning_of_quarter,
    :beginning_of_year,
    :beginning_of_week,
    :end_of_month,
    :end_of_quarter,
    :end_of_year,
    :end_of_week
  ]
  def try_to_calculate(
        changeset,
        _information,
        %Date{} = value
      ) do
    {changeset, value}
  end

  def try_to_calculate(
        changeset,
        _information,
        value
      )
      when value in @date_types do
    {changeset, Utils.resolve_date(value)}
  end

  def try_to_calculate(
        changeset,
        _information,
        %Decimal{} = value
      ) do
    {changeset, value}
  end

  def try_to_calculate(
        changeset,
        _information,
        value
      )
      when is_float(value) do
    {changeset, Decimal.from_float(value)}
  end

  def try_to_calculate(
        changeset,
        _information,
        value
      )
      when is_integer(value) do
    {changeset, Decimal.new(value)}
  end

  def try_to_calculate(
        changeset,
        information,
        {:field, field}
      )
      when is_atom(field) do
    changeset = Utils.ensure_variable(changeset, information, field)
    {changeset, Changeset.get_field(changeset, field)}
  end

  def try_to_calculate(
        changeset,
        information,
        {method, %Date{} = date, {unit, count}}
      )
      when method in [:add, :subt] and unit in [:months, :days, :weeks, :years] do
    {changeset, count} = try_to_calculate(changeset, information, count)

    date = prepare_days_and_months(method, unit, count, date)
    {changeset, date}
  end

  def try_to_calculate(
        changeset,
        information,
        {operation, left, right}
      )
      when operation in [:add, :subt, :mult, :div, :pow, :eq] and
             is_nil(left) do
    try_to_calculate(changeset, information, {operation, 0, right})
  end

  def try_to_calculate(
        changeset,
        information,
        {operation, left, right}
      )
      when operation in [:add, :subt, :mult, :div, :pow, :eq] and
             is_nil(right) do
    try_to_calculate(changeset, information, {operation, left, 0})
  end

  # in case of left side is not resolved
  def try_to_calculate(
        changeset,
        information,
        {operation, left = {_, _, _}, right}
      ) do
    {changeset, result} = try_to_calculate(changeset, information, left)
    try_to_calculate(changeset, information, {operation, result, right})
  end

  # in case of right side is not resolved
  def try_to_calculate(
        changeset,
        information,
        {operation, left, right = {_, _, _}}
      ) do
    {changeset, result} = try_to_calculate(changeset, information, right)
    try_to_calculate(changeset, information, {operation, left, result})
  end

  # in case of left side is a variable
  def try_to_calculate(
        changeset,
        information,
        {operation, {:field, _left_field} = left, right}
      ) do
    {changeset, result} = try_to_calculate(changeset, information, left)

    try_to_calculate(
      changeset,
      information,
      {operation, result, right}
    )
  end

  # in case of right side is a variable
  def try_to_calculate(
        changeset,
        information,
        {operation, left, {:field, _right_field} = right}
      ) do
    {changeset, result} = try_to_calculate(changeset, information, right)

    try_to_calculate(
      changeset,
      information,
      {operation, left, result}
    )
  end

  # perform addition operation
  def try_to_calculate(
        changeset,
        _information,
        {:add, left, right}
      )
      when is_number(left) and is_number(right) do
    {changeset, left + right}
  end

  def try_to_calculate(
        changeset,
        _information,
        {:add, left, right}
      )
      when not is_nil(left) and not is_nil(right) do
    {changeset, Decimal.add(left, right)}
  end

  # perform subtract operation
  def try_to_calculate(
        changeset,
        _information,
        {:subt, left, right}
      )
      when is_number(left) and is_number(right) do
    {changeset, left - right}
  end

  def try_to_calculate(
        changeset,
        _information,
        {:subt, left, right}
      )
      when not is_nil(left) and not is_nil(right) do
    {changeset, Decimal.sub(left, right)}
  end

  # perform multiplication operation
  def try_to_calculate(
        changeset,
        _information,
        {:mult, left, right}
      )
      when is_number(left) and is_number(right) do
    {changeset, left * right}
  end

  def try_to_calculate(
        changeset,
        _information,
        {:mult, left, right}
      )
      when not is_nil(left) and not is_nil(right) do
    {changeset, Decimal.mult(left, right)}
  end

  # perform division operation
  def try_to_calculate(
        changeset,
        _information,
        {:div, left, right}
      )
      when is_number(left) and is_number(right) and right != 0 do
    {changeset, left / right}
  end

  def try_to_calculate(
        changeset,
        _information,
        {:div, left, right}
      )
      when not is_nil(left) and not is_nil(right) do
    try do
      {changeset, Decimal.div(left, right)}
    rescue
      _ ->
        {changeset, nil}
    end
  end

  # perform power operation
  def try_to_calculate(
        changeset,
        _information,
        {:pow, left, right}
      )
      when is_number(left) and is_number(right) do
    try do
      {changeset, :math.pow(left, right)}
    rescue
      _ ->
        {changeset, nil}
    end
  end

  def try_to_calculate(
        changeset,
        _information,
        {:pow, %Decimal{} = left, %Decimal{} = right}
      ) do
    try do
      left = Decimal.to_float(left)
      right = Decimal.to_float(right)
      result = left |> :math.pow(right) |> Decimal.from_float()
      {changeset, result}
    rescue
      _ ->
        {changeset, nil}
    end
  end

  # perform eq operation
  def try_to_calculate(
        changeset,
        information,
        {:eq, left, right}
      )
      when is_number(left) and is_number(right) do
    try_to_calculate(
      changeset,
      information,
      {:eq, Utils.cast_decimal(left), Utils.cast_decimal(right)}
    )
  end

  def try_to_calculate(
        changeset,
        information,
        {:eq, %Decimal{} = left, right}
      )
      when is_number(right) do
    try_to_calculate(
      changeset,
      information,
      {:eq, left, Utils.cast_decimal(right)}
    )
  end

  def try_to_calculate(
        changeset,
        information,
        {:eq, left, %Decimal{} = right}
      )
      when is_number(left) do
    try_to_calculate(
      changeset,
      information,
      {:eq, Utils.cast_decimal(left), right}
    )
  end

  def try_to_calculate(
        changeset,
        _information,
        {:eq, %Decimal{} = left, %Decimal{} = right}
      ) do
    {changeset, Decimal.eq?(left, right)}
  end

  def try_to_calculate(
        changeset,
        _information,
        {:eq, right, right}
      ),
      do: {changeset, true}

  def try_to_calculate(
        changeset,
        _information,
        {:eq, _left, _right}
      ),
      do: {changeset, false}

  def try_to_calculate(
        changeset,
        information,
        {operation, left, right}
      )
      when operation in [:and, :or] do
    valid? = Checker.valid?(changeset, information, {operation, left, right})
    {changeset, valid?}
  end

  def try_to_calculate(
        changeset,
        _information,
        {operation, assoc, field}
      )
      when operation in [:sum, :max, :min] do
    method =
      case operation do
        :sum -> :add
        :min -> :min
        :max -> :max
      end

    {changeset, Utils.calculate_aggregate_value(changeset, assoc, field, method)}
  end

  # log missing operation
  def try_to_calculate(
        changeset,
        _information,
        operation
      ) do
    Logger.error("SKIPPING Operation #{inspect(operation)}")
    {changeset, nil}
  end

  defp prepare_days_and_months(method, unit, %Decimal{} = value, date),
    do: prepare_days_and_months(method, unit, Decimal.to_integer(value), date)

  defp prepare_days_and_months(method, unit, number, date) when is_float(number),
    do: prepare_days_and_months(method, unit, floor(number), date)

  defp prepare_days_and_months(:add, unit, number, date) when is_integer(number),
    do: prepare_days_and_months(unit, number, date)

  defp prepare_days_and_months(:subt, unit, number, date) when is_integer(number),
    do: prepare_days_and_months(unit, number * -1, date)

  defp prepare_days_and_months(method, unit, _, date),
    do: prepare_days_and_months(method, unit, 0, date)

  defp prepare_days_and_months(_, 0, date), do: date
  defp prepare_days_and_months(:months, count, date), do: Timex.shift(date, months: count)
  defp prepare_days_and_months(:days, count, date), do: Timex.shift(date, days: count)
  defp prepare_days_and_months(:weeks, count, date), do: Timex.shift(date, weeks: count)
  defp prepare_days_and_months(:years, count, date), do: Timex.shift(date, years: count)
end
