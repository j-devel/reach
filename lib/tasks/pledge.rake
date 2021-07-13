# -*- ruby -*-

require 'pledge'
require '../../rb/minerva_xstd'

namespace :reach do

  def setup_voucher_request
    @idevid     = ENV['IDEVID']
    @productid  = ENV['PRODUCTID']
    @jrcurl  = ENV['JRC']

    if (!@idevid and !@productid)
      puts "Must set IDEVID=xx or PRODUCTID=zz"
      exit
    end

    unless @jrcurl
      puts "Must Set JRC=url"
      exit
    end

    if @productid
      PledgeKeys.instance.product_id = @productid
    else
      PledgeKeys.instance.idevid = @idevid
    end
  end

  # generate an unsigned voucher request
  desc "construct a unsigned voucher request IDEVID=xx/PRODUCTID=zz, send to JRC=yy"
  task :send_unsigned_voucher_request => :environment do
    setup_voucher_request

    client = Pledge.new
    client.jrc = @jrcurl

    voucher = client.get_voucher_with_unsigned(true)

    unless voucher
      puts "no voucher returned"
      exit 10
    end

    client.voucher_validate!(voucher)

    # Registrar is now authenticated!
  end

  # generate a voucher request with the
  # proximity-registrar-cert filled in
  # and send it to the appropriate Registrar.
  desc "enroll using CoAP to with IDEVID=xx/PRODUCTID=zz, send to JRC=yy"
  task :enroll_coap_pledge => :environment do
    setup_voucher_request

    client = Pledge.new
    client.jrc = @jrcurl

    voucher = client.get_constrained_voucher(true)
    # now enroll using /simpleenroll

    unless client.voucher_validate!(voucher)
      puts "Failed to validate voucher"
      exit 1
    end
    client.enroll(true)
  end

  def test_ruby_to_rust
    puts "==== 🧪 test_ruby_to_rust"
    unless MinvervaXstd.ruby_to_rust == 8
      puts "@@ test ruby_to_rust -- [fail]"
    end
  end

  def test_validate_voucher_pkcs
    puts "==== 🧪 test_validate_voucher_pkcs"

    setup_voucher_request

    raw_voucher = "trentonio/voucher_00-d0-e5-02-00-2e.pkcs"  # cms+json
    File.open(raw_voucher, "rb") do |f|
      rv = f.read

      unless MinvervaXstd.voucher_validate(rv)
        puts "@@ WIP !!!! validate voucher in Rust -- [fail]"
      end

      voucher = Chariwt::Voucher.from_pkcs7(rv, PledgeKeys.instance.vendor_ca)
      puts "@@ pinnedDomainCert: #{voucher.pinnedDomainCert}"
#       puts "@@ pinnedDomainCert.subject: #{voucher.pinnedDomainCert.subject}"
#       puts "@@ pinnedDomainCert.subject.to_s: #{voucher.pinnedDomainCert.subject.to_s}"
#       puts "@@ pinnedDomainCert.to_der: #{voucher.pinnedDomainCert.to_der}"
    end
  end

  def test_validate_voucher_cose
    puts "==== 🧪 test_validate_voucher_cose"

    raw_voucher = "../chariwt/spec/files/voucher_jada123456789.vch"  # cose
    File.open(raw_voucher, "rb") do |f|
      rv = f.read

      # Rust

      unless MinvervaXstd.voucher_validate(rv)
        puts "@@ WIP !!!! validate voucher in Rust -- [fail]"
      end

      # Ruby

      puts "@@ Using the unmatching `raw_voucher`, `validate_from_chariwt()` of voucher.rb will fail for now; that's ok"

      #==== via `client`
#       client = Pledge.new
#       voucher = client.process_constrained_content_type(65502, rv)
      #==== via chariwt
      voucher = Chariwt::Voucher.from_cbor_cose(rv, PledgeKeys.instance.masa_cert)
      #====

      puts "@@ pinnedDomainCert: #{voucher.pinnedDomainCert}"
    end
  end

  desc "test Rust-based minerva implementation"
  task :test_minverva_xstd => :environment do
    test_ruby_to_rust

#     test_validate_voucher_pkcs
    test_validate_voucher_cose
  end

  # generate a voucher request with the
  # proximity-registrar-cert filled in
  # and send it to the appropriate Registrar.
  desc "enroll using HTTP to with IDEVID=xx/PRODUCTID=zz, send to JRC=yy"
  task :enroll_http_pledge => :environment do
    puts "@@ enroll_http_pledge(): hello"

    setup_voucher_request

    client = Pledge.new
    client.jrc = @jrcurl

    puts "@@ before client.get_voucher()"
#    exit 99

    voucher = client.get_voucher(true)
    # now enroll using /simpleenroll

    exit 3 unless voucher

    puts "@@ before client.voucher_validate!()"
#    exit 99

    raw_voucher = client.instance_variable_get(:@raw_voucher) # kludge
    unless MinvervaXstd.voucher_validate(raw_voucher)
      puts "@@ WIP !!!! validate voucher in Rust"
    end

    unless client.voucher_validate!(voucher)
      puts "Failed to validate voucher"
      exit 1
    end
    client.enroll(true)
  end

  # do an EST simpleenroll with a trusted IDevID
  desc "send a certificate signing request for PRODUCTID=zz, to JRC=yy"
  task :simple_enroll => :environment do
    client = Pledge.new
    client.jrc = @jrcurl

    # will write the CSR to a file
    client.enroll(true)
  end


  # generate a CWT voucher request with the
  # proximity-registrar-public-key filled in
  # and send it to the connected Registrar.
  desc "construct an (unsigned) CWT voucher request from PRODUCTID=xx, send to JRC=yy"
  task :send_constrained_request => :environment do
    productid  = ENV['PRODUCTID']
    idevid  = ENV['IDEVID']
    jrcurl  = ENV['JRC']

    if (!idevid and !productid)
      puts "Must set IDEVID=xx or PRODUCTID=zz"
      exit
    end

    unless jrcurl
      puts "Must Set JRC=url"
      exit
    end

    if productid
      PledgeKeys.instance.product_id = productid
    else
      PledgeKeys.instance.idevid = idevid
    end

    client = Pledge.new
    client.jrc = jrcurl

    voucher = client.get_constrained_voucher(true)

    unless voucher
      puts "no voucher returned"
      exit 10
    end

    client.voucher_validate!(voucher)
  end

  # parse a DPP file and enroll an IDevID with the indicated MASA
  desc "parse DPPFILE=file and send it up (to MASAURL=url)"
  task :dpp_idevid_enroll => :environment do
    dppfile=ENV['DPPFILE']
    unless ENV['MASAURL'].blank?
      masaurl = ENV['MASAURL']
    end

    dpp = DPPCode.new(IO::read("spec/files/dpp1.txt"))

    sk = SmartPledge.new
    sk.enroll_with_smartpledge_manufacturer(dpp)

    # Registrar is now authenticated!
  end



end
