require 'dns_validator'


class Record < ActiveRecord::Base
  self.inheritance_column = :itype

  ##
  # Type validation can be suppressed by setting this attribute to a
  # non-zero value

  attr_accessor :no_type_validation

  ##
  # Array of all available resource record types we can handle currently.

  Types = %w(A AAAA AFSDB CERT CNAME DLV DNAME DNSKEY DS EUI48 EUI64
             HINFO KEY LOC MINFO MX NAPTR NS NSEC NSEC3 NSEC3PARAM OPT
             PTR RKEY RP RRSIG SOA SPF SSHFP SRV TLSA TXT).freeze


  belongs_to :domain
  has_many :users, through: :domain

  ##
  # Sort a Record collection in a sane order. We want SOA records first,
  # then NS and the rest ordered by its name and type.
  # This scope is intended to be used for ordering of resource records
  # for a single domain.

  scope :type_sort, -> do
    order("records.type != 'SOA'", "records.type != 'NS'", :name, :type)
  end

  scope :last_changed, ->(num) do
    order(:change_date).reverse_order.limit(num)
  end

  before_validation { process_name }

  before_save do
    self.hash_zone_record if self.domain.cryptokeys.any?
    self.ttl ||= 86400
  end


  validates :name, presence: true
  validates :domain_id, presence: true
  validates :domain, associated: true
  validates :type, presence: true
  validates :token, uniqueness: true, length: {minimum: 64, maximum: 255},
    allow_blank: true
  validates_inclusion_of :type, in: Types
  validate :unique_record
  validate do |record|
    if has_dns_validator? and record.no_type_validation.to_i.zero?
      klass = DNSValidator::ResourceRecord.class_eval self.type
      klass.new(record).validate
    end
  end


  ##
  # Hash the recordname for a zone according to its NSEC3 settings.
  # It does nothing if the zone doesn't use NSEC3.

  def hash_zone_record
    return unless self.domain.domainmetadata.where(kind: 'NSEC3PARAM').any?

    IO.popen("pdnssec hash-zone-record #{self.domain.name} #{self.name}") do |res|
      res.each do |line|
        self.ordername = line
      end
    end
  end


  ##
  # Check if a DNS validator is available for the resource record type
  # of this instance.

  def has_dns_validator?
    types = DNSValidator::ResourceRecord.constants
    !!(self.type and types.include? self.type.to_sym)
  end


  ##
  # Generate a random token for token based updating.

  def generate_token
    input_string = (Time.now.tv_sec + Random.rand(2**32)).to_s
    self.token = Digest::SHA384.base64digest(input_string).gsub(/[+\/]/,"-")
  end


  private

  ##
  # Validation method which should avoid duplicate resource records.

  def unique_record
    if Record.where(name: self.name,
                    type: self.type,
                    prio: self.prio,
                    content: self.content).where.not(id: self.id).any?

      errors.add(:base, :record_exists)
    end
  end


  ##
  # Before a Record can be saved we need to make sure that the name
  # doesn't end with a '.' and set or add the domain name if it isn't
  # present yet.

  def process_name
    return unless self.domain

    self.name = self.name.blank? ? self.domain.name : self.name.chomp('.')

    unless self.name =~ /#{self.domain.name.gsub('.','\.')}\z/
      self.name += '.' + self.domain.name
    end
  end

end
