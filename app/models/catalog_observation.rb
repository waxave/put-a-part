class CatalogObservation < ApplicationRecord
  belongs_to :processing_record
  has_many :catalog_assertions, dependent: :nullify
  has_many :vehicle_candidates, dependent: :nullify
  has_many :reviewed_applications, dependent: :destroy
  has_many :reviewed_attributes, dependent: :destroy
  has_many :reviewed_catalog_fields, dependent: :destroy
  has_many :reviewed_interchanges, dependent: :destroy

  validates :source_key, :source_url, :source_sku, presence: true
  validates :status, inclusion: { in: %w[candidate] }

  def safe_source_url
    uri = URI.parse(source_url.to_s)
    return source_url if source_key == "autofacts" && uri.is_a?(URI::HTTPS) &&
      %w[autofactsdb.com simepa.mx catalog.elginind.com].include?(uri.host) && uri.port == 443 &&
      uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
    return source_url if source_key == "rexite" && uri.is_a?(URI::HTTPS) && uri.host == "rexite.net" && uri.port == 443 && uri.userinfo.nil?
    return source_url if source_key == "hastings" && uri.is_a?(URI::HTTPS) && uri.host == "hastings.apacatalog.com" && uri.port == 443 && uri.userinfo.nil? && uri.path.match?(%r{\A/Home/partdetail/\d{1,20}\z}) && uri.query.nil? && uri.fragment.nil?
    return source_url if source_key == "rockauto" && CatalogIntelligence::Connectors::Rockauto.safe_url?(source_url)
    source_url if source_key == "brave_search" && CatalogIntelligence::Connectors::BraveSearch.safe_url?(source_url)
  rescue URI::InvalidURIError
    nil
  end
end
