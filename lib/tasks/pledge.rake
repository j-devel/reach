# -*- ruby -*-

require 'pledge'

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

  # https://github.com/alexcrichton/rust-ffi-examples/tree/master/ruby-to-rust
  module Hello
    extend FFI::Library
    puts "@@ Hello -- Dir.pwd: #{Dir.pwd}"
    ffi_lib '../../target/debug/libdouble_input.' + FFI::Platform::LIBSUFFIX
    attach_function :double_input, [ :int ], :int
  end

  def test_ruby_to_rust
    input = 4
    output = Hello.double_input(input)
    puts "@@ test_ruby_to_rust -- #{input} * 2 = #{output}"
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

  # generate a voucher request with the
  # proximity-registrar-cert filled in
  # and send it to the appropriate Registrar.
  desc "enroll using HTTP to with IDEVID=xx/PRODUCTID=zz, send to JRC=yy"
  task :enroll_http_pledge => :environment do
    puts "@@ enroll_http_pledge(): hello"

    test_ruby_to_rust  # @@

    setup_voucher_request

    client = Pledge.new
    client.jrc = @jrcurl

    puts "@@ before client.get_voucher()"
    exit 99

    voucher = client.get_voucher(true)
    # now enroll using /simpleenroll

    exit 3 unless voucher

    puts "@@ before client.voucher_validate!()"
    #exit 99

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
