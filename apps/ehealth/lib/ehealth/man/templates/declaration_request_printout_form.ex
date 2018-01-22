defmodule EHealth.Man.Templates.DeclarationRequestPrintoutForm do
  @moduledoc false

  alias EHealth.API.Man
  alias EHealth.Utils.AddressMerger
  alias EHealth.Dictionaries
  alias EHealth.DeclarationRequest

  use Confex, otp_app: :ehealth

  @auth_otp DeclarationRequest.authentication_method(:otp)
  @auth_offline DeclarationRequest.authentication_method(:offline)

  @documents_dict "DOCUMENT_TYPE"
  @relationship_documents_dict "DOCUMENT_RELATIONSHIP_TYPE"

  def render(declaration_request, authentication_method_current) do
    template_data =
      declaration_request
      |> map_declaration_data(authentication_method_current)
      |> Map.put(:format, config()[:format])
      |> Map.put(:locale, config()[:locale])

    template_id = config()[:id]

    Man.render_template(template_id, template_data)
  end

  defp map_declaration_data(nil, _), do: %{}

  defp map_declaration_data(declaration_request, authentication_method_current) do
    %{
      person: get_person(declaration_request),
      employee: get_employee(declaration_request),
      division: get_division(declaration_request),
      legal_entity: get_legal_entity(declaration_request),
      confidant_persons: check_confidant_persons(declaration_request),
      authentication_method_current: get_authentication_method_current(authentication_method_current),
      declaration_id: Map.get(declaration_request, "declaration_id", "")
    }
  end

  defp get_person(declaration_request) do
    person = Map.get(declaration_request, "person", %{})

    %{
      full_name: get_full_name(person),
      gender: get_gender(person),
      birth_date: Map.get(person, "birth_date", ""),
      document: get_document(person, "documents", @documents_dict),
      birth_settlement: Map.get(person, "birth_settlement", ""),
      birth_country: Map.get(person, "birth_country", ""),
      tax_id: Map.get(person, "tax_id", ""),
      addresses: get_person_addresses(person),
      phones: get_phone(person),
      email: Map.get(person, "email", ""),
      secret: Map.get(person, "secret", ""),
      emergency_contact: get_emergency_contact(person),
      confidant_person: get_confidant_persons(person)
    }
  end

  defp get_full_name(person) do
    first_name = Map.get(person, "first_name")
    second_name = Map.get(person, "second_name")
    last_name = Map.get(person, "last_name")

    [first_name, second_name, last_name]
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(" ")
  end

  defp get_gender(person) do
    gender = %{
      male: false,
      female: false
    }

    case Map.get(person, "gender") do
      "MALE" -> Map.put(gender, :male, true)
      "FEMALE" -> Map.put(gender, :female, true)
      _ -> gender
    end
  end

  defp get_document(person, key, dictionary_name) do
    case Map.get(person, key) do
      [first | _other] -> first |> take_fields(["type", "number"]) |> update_document_type(dictionary_name)
      _ -> %{"type" => "", "number" => ""}
    end
  end

  defp update_document_type(document, dictionary_name) do
    Map.update!(document, "type", fn type -> Dictionaries.get_dictionary_value(type, dictionary_name) end)
  end

  defp get_person_addresses(person) do
    addresses = Map.get(person, "addresses", [])
    registration_address = Enum.find(addresses, fn address -> Map.get(address, "type") == "REGISTRATION" end)
    residence_address = Enum.find(addresses, fn address -> Map.get(address, "type") == "RESIDENCE" end)

    full_registration_address =
      case registration_address do
        nil -> ""
        address -> AddressMerger.merge_address(address)
      end

    full_residence_address =
      case residence_address do
        nil -> ""
        address -> AddressMerger.merge_address(address)
      end

    %{
      registration: %{
        full_address: full_registration_address
      },
      residence: %{
        full_address: full_residence_address
      }
    }
  end

  defp get_phone(data) do
    case Map.get(data, "phones") do
      [first | _other] -> take_fields(first, ["number"])
      _ -> %{"number" => ""}
    end
  end

  defp take_fields(data, fields) when is_map(data), do: Map.take(data, fields)
  defp take_fields(_, _), do: %{}

  defp get_emergency_contact(person) do
    emergency_contact = Map.get(person, "emergency_contact", %{})

    %{
      full_name: get_full_name(emergency_contact),
      phones: get_phone(emergency_contact)
    }
  end

  defp get_confidant_persons(person) do
    confidant_persons = Map.get(person, "confidant_person", [])

    primary_confidant_person =
      confidant_persons
      |> Enum.find(fn x -> Map.get(x, "relation_type") == "PRIMARY" end)
      |> get_confidant_person()

    secondary_confidant_person =
      confidant_persons
      |> Enum.find(fn x -> Map.get(x, "relation_type") == "SECONDARY" end)
      |> get_confidant_person()

    %{
      primary: primary_confidant_person,
      secondary: secondary_confidant_person
    }
  end

  defp get_confidant_person(nil), do: %{}

  defp get_confidant_person(confidant_person) do
    %{
      full_name: get_full_name(confidant_person),
      phones: get_phone(confidant_person),
      birth_date: Map.get(confidant_person, "birth_date", ""),
      gender: get_gender(confidant_person),
      birth_settlement: Map.get(confidant_person, "birth_settlement", ""),
      birth_country: Map.get(confidant_person, "birth_country", ""),
      documents_person: get_document(confidant_person, "documents_person", @documents_dict),
      tax_id: Map.get(confidant_person, "tax_id", ""),
      documents_relationship: get_document(confidant_person, "documents_relationship", @relationship_documents_dict)
    }
  end

  defp get_employee(declaration_request) do
    employee = Map.get(declaration_request, "employee", %{})
    party = Map.get(employee, "party", %{})

    %{
      full_name: get_full_name(party),
      phones: get_phone(party),
      email: Map.get(party, "email", "")
    }
  end

  defp get_division(declaration_request) do
    division = Map.get(declaration_request, "division", %{})

    %{
      addresses: get_division_addresses(division)
    }
  end

  defp get_division_addresses(division) do
    addresses = Map.get(division, "addresses", [])
    registration_address = Enum.find(addresses, fn address -> Map.get(address, "type") == "REGISTRATION" end)

    full_street =
      case registration_address do
        nil -> ""
        address -> address |> AddressMerger.merge_street_part() |> List.first()
      end

    settlement =
      case registration_address do
        nil -> ""
        address -> address |> AddressMerger.merge_settlement_part(full_street) |> List.first()
      end

    %{
      registration: %{
        full_street: full_street,
        settlement: settlement
      }
    }
  end

  defp get_legal_entity(declaration_request) do
    legal_entity = Map.get(declaration_request, "legal_entity", %{})

    %{
      full_name: Map.get(legal_entity, "public_name", ""),
      addresses: get_legal_entity_addresses(legal_entity),
      edrpou: Map.get(legal_entity, "edrpou", ""),
      full_license: get_three_licenses(legal_entity),
      phones: get_phone(legal_entity),
      email: Map.get(legal_entity, "email", "")
    }
  end

  defp get_legal_entity_addresses(legal_entity) do
    addresses = Map.get(legal_entity, "addresses", [])
    registration_address = Enum.find(addresses, fn address -> Map.get(address, "type") == "REGISTRATION" end)

    full_address =
      case registration_address do
        nil -> ""
        address -> AddressMerger.merge_address(address)
      end

    %{
      registration: %{
        full_address: full_address
      }
    }
  end

  defp get_three_licenses(legal_entity) do
    licenses =
      case Map.get(legal_entity, "licenses") do
        licenses when is_list(licenses) -> Enum.take(licenses, 3)
        _ -> %{}
      end

    licenses
    |> Enum.map(&get_license_info(&1))
    |> Enum.join(", ")
  end

  defp get_license_info(license) do
    license_number = Map.get(license, "license_number")
    issued_date = Map.get(license, "issued_date")

    "#{license_number} (#{issued_date})"
  end

  defp check_confidant_persons(declaration_request) do
    person = Map.get(declaration_request, "person", %{})
    confidant_persons = Map.get(person, "confidant_person", [])
    secondary_confidant_person = Enum.find(confidant_persons, fn x -> Map.get(x, "relation_type") == "SECONDARY" end)

    %{
      exist: length(confidant_persons) > 0,
      secondary: secondary_confidant_person != nil
    }
  end

  defp get_authentication_method_current(data) do
    authentication_method_current = %{
      otp: false,
      offline: false
    }

    case Map.get(data, "type") do
      @auth_otp -> Map.put(authentication_method_current, :otp, true)
      @auth_offline -> Map.put(authentication_method_current, :offline, true)
      _ -> authentication_method_current
    end
  end
end
