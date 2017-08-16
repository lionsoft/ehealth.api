defmodule EHealth.Factories do
  @moduledoc false

  use ExMachina

  # PRM
  use EHealth.PRMFactories.LegalEntityFactory
  use EHealth.PRMFactories.MedicalServiceProviderFactory
  use EHealth.PRMFactories.GlobalParameterFactory
  use EHealth.PRMFactories.UkrMedRegistryFactory
  use EHealth.PRMFactories.DivisionFactory
  use EHealth.PRMFactories.EmployeeFactory
  use EHealth.PRMFactories.EmployeeDoctorFactory
  use EHealth.PRMFactories.PartyFactory

  # IL
  use EHealth.ILFactories.DictionaryFactory
  use EHealth.ILFactories.EmployeeRequestFactory

  alias EHealth.Repo
  alias EHealth.PRMRepo

  def insert(type, factory, attrs \\ []) do
    factory
    |> build(attrs)
    |> repo_insert!(type)
  end

  defp repo_insert!(data, :il), do: Repo.insert!(data)
  defp repo_insert!(data, :prm), do: PRMRepo.insert!(data)
end
