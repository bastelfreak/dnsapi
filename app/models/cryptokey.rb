class Cryptokey < ActiveRecord::Base
  self.inheritance_column = :itype

  enum flags: {
    ZSK: 256,
    KSK: 257
  }

  belongs_to :domain, inverse_of: :cryptokeys

  validates :domain_id, presence: true
  validates :domain, associated: true
  validates :flags, presence: true
  validates :content, presence: true
end
