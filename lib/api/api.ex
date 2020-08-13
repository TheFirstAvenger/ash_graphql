defmodule AshGraphql.Api do
  @moduledoc "The entrypoint for adding graphql behavior to an Ash API"

  @graphql %Ash.Dsl.Section{
    name: :graphql,
    describe: """
    Global configuration for graphql
    """,
    schema: [
      authorize?: [
        type: :boolean,
        doc: "Whether or not to perform authorization for this API",
        default: true
      ]
    ]
  }

  use Ash.Dsl.Extension, sections: [@graphql]

  def authorize?(api) do
    Extension.get_opt(api, :api, :authorize?, true)
  end

  @doc false
  def queries(api, schema) do
    api
    |> Ash.Api.resources()
    |> Enum.flat_map(&AshGraphql.Resource.queries(api, &1, schema))
  end

  @doc false
  def mutations(api, schema) do
    api
    |> Ash.Api.resources()
    |> Enum.filter(fn resource ->
      AshGraphql.Resource in Ash.Resource.extensions(resource)
    end)
    |> Enum.flat_map(&AshGraphql.Resource.mutations(api, &1, schema))
  end

  @doc false
  def type_definitions(api, schema) do
    resource_types =
      api
      |> Ash.Api.resources()
      |> Enum.filter(fn resource ->
        AshGraphql.Resource in Ash.Resource.extensions(resource)
      end)
      |> Enum.flat_map(fn resource ->
        AshGraphql.Resource.type_definitions(resource, schema) ++
          AshGraphql.Resource.mutation_types(resource, schema)
      end)

    [mutation_error(schema), relationship_change(schema)] ++ resource_types
  end

  defp relationship_change(schema) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "A set of changes to apply to a relationship",
      fields: relationship_change_fields(schema),
      identifier: :relationship_change,
      module: schema,
      name: "RelationshipChange"
    }
  end

  defp relationship_change_fields(schema) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Ids to add to the relationship",
        identifier: :add,
        module: schema,
        name: "add",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: :id
        }
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "Ids to remove from the relationship",
        identifier: :remove,
        module: schema,
        name: "remove",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: :id
        }
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description:
          "Ids to replace the relationship with. Takes precendence over removal and addition",
        identifier: :replace,
        module: schema,
        name: "replace",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: :id
        }
      }
    ]
  end

  defp mutation_error(schema) do
    %Absinthe.Blueprint.Schema.ObjectTypeDefinition{
      description: "An error generated by a failed mutation",
      fields: error_fields(schema),
      identifier: :mutation_error,
      module: schema,
      name: "MutationError"
    }
  end

  defp error_fields(schema) do
    [
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The human readable error message",
        identifier: :message,
        module: schema,
        name: "message",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "An error code for the given error",
        identifier: :code,
        module: schema,
        name: "code",
        type: :string
      },
      %Absinthe.Blueprint.Schema.FieldDefinition{
        description: "The field or fields that produced the error",
        identifier: :fields,
        module: schema,
        name: "fields",
        type: %Absinthe.Blueprint.TypeReference.List{
          of_type: :string
        }
      }
    ]
  end
end