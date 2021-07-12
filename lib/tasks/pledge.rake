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

  #

  module MinvervaXstd
    extend FFI::Library
    puts "@@ MinvervaXstd -- Dir.pwd: #{Dir.pwd}"
    ffi_lib '../../target/debug/libminerva_xstd.' + FFI::Platform::LIBSUFFIX

    attach_function :rs_double_input, [ :int ], :int
    attach_function :rs_voucher_validate, [ :pointer, :uint ], :bool

    # https://github.com/alexcrichton/rust-ffi-examples/tree/master/ruby-to-rust
    def self.test_ruby_to_rust
      input = 4
      output = rs_double_input(input)
      puts "@@ test_ruby_to_rust -- #{input} * 2 = #{output}"
    end

    # https://github.com/ffi/ffi/wiki/Binary-data
    def self.voucher_validate(data)
      # https://www.rubydoc.info/github/ffi/ffi/FFI/MemoryPointer
      rs_voucher_validate(FFI::MemoryPointer.from_string(data), data.bytesize)
    end
  end

  #

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

  desc "test Rust-based minerva implementation"
  task :test_minverva_xstd => :environment do

    MinvervaXstd.test_ruby_to_rust

    # feed the cached raw voucher
    File.open("tmp/voucher_00-d0-e5-02-00-2e.pkcs", "rb") do |f|
      unless MinvervaXstd.voucher_validate(f.read)
        puts "@@ WIP !!!! validate voucher in Rust"
      end
    end

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
