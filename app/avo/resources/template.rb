class Avo::Resources::Template < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :title, as: :text
    field :content, as: :textarea
    field :user, as: :belongs_to
  end
end
