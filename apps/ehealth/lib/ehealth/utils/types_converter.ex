defmodule EHealth.Utils.TypesConverter do
  @moduledoc """
  Helps convert types
  """
  def strings_to_keys(%{} = map) do
    for {key, val} <- map, into: %{}, do: {string_to_atom(key), strings_to_keys(val)}
  end

  def strings_to_keys(val) when is_list(val), do: Enum.map(val, &strings_to_keys(&1))
  def strings_to_keys(val), do: val

  def string_to_atom(string) when is_binary(string), do: String.to_atom(string)
  def string_to_atom(atom), do: atom

  def string_to_integer(string) when is_binary(string), do: String.to_integer(string)
  def string_to_integer(string), do: string
end
