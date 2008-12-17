require File.dirname(__FILE__) + '/../test_helper'

class RemoteIdealIngPostbankTest < Test::Unit::TestCase
  include ActiveMerchant::Billing
  
  def setup
    Base.gateway_mode = :test

    @gateway = IdealIngPostbankGateway.new(fixtures(:ideal_ing_postbank))

    @options = {
      :issuer_id =>'0151', 
      
      #:expiration_period=>'PT10M', 
      :return_url =>'http://www.return.url', 
      :order_id =>'1234567890123456', 
      :currency =>'EUR', 
      :description => 'A description', 
      :entrance_code => '1234'
    }
  end
  
  def test_issuers        
    response = @gateway.issuers
    p response
    
    list = response.issuer_list
    
    p list
  
    assert_equal 1, list.length
    assert_equal "Issuer Simulator", list[0][ "issuerName" ]
    assert_equal "0151", list[0]["issuerID"]
    assert_equal "Short", list[0]["issuerList"]
  end


  def test_set_purchase
    response = @gateway.setup_purchase(550, @options)
    p response
    
    assert_success response
    assert response.test?
    assert_nil response.error, "Response should not have an error"
  end  

  def test_return_errors    
    response = @gateway.setup_purchase(0.5, @options)
    assert_failure response, "Should fail"
    assert_equal "BR1210", response.error[ 'errorCode']
    assert_not_nil response.error[ 'errorMessage'],  "Response should contain an Error message"
    assert_not_nil response.error[ 'errorDetail'],   "Response should contain an Error Detail message" 
    assert_not_nil response.error['consumerMessage'],"Response should contain an Consumer Error message"    
  end
  
  # default payment should succeed
  def test_purchase_successful
    # first setup the payment
    response = @gateway.setup_purchase(2599, @options)
    
    assert_success response, "Setup should succeed."

    assert_equal "1234567890123456", response.transaction['purchaseID']
    assert_equal "0050", response.params['AcquirerTrxRes']['Acquirer'][ 'acquirerID']    
    assert_not_nil response.service_url, "Response should contain a service url for payment"
        
    # now authorize the payment, issuer simulator has completed the payment 
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])

    assert_success response, 'Transaction should succeed'
    assert_equal "Success", response.transaction['status']
    assert_equal "DEN HAAG", response.transaction['consumerCity']
    assert_equal "C M Bröcker-Meijer en M Bröcker", response.transaction['consumerName'] 
  end

  # payment of 200 should cancel
  def test_purchase_cancel
    # first setup the payment
    response = @gateway.setup_purchase(200, @options)
    
    assert_success response, "Setup should succeed."    
    # now try to authorize the payment, issuer simulator has cancelled the payment 
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])

    assert_failure response, 'Transaction should cancel'
    assert_equal "Cancelled", response.transaction['status'], 'Transaction should cancel'
  end

  # payment of 300 should expire  
  def test_transaction_expired       
    # first setup the payment
    response = @gateway.setup_purchase(300, @options)

    # now try to authorize the payment, issuer simulator let the payment expire
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])
    
    assert_failure response, 'Transaction should expire'
    assert_equal "Expired", response.transaction['status'], 'Transaction should expire'    
  end

  # payment of 400 should remain open
  def test_transaction_expired       
    # first setup the payment
    response = @gateway.setup_purchase(400, @options)

    # now try to authorize the payment, issuer simulator keeps the payment open
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])
    
    assert_failure response, 'Transaction should remain open'
    assert_equal "Open", response.transaction['status'], 'Transaction should remain open'    
  end

  # payment of 500 should fail at issuer
  def test_transaction_expired       
    # first setup the payment
    response = @gateway.setup_purchase(500, @options)

    # now try to authorize the payment, issuer simulator lets the payment fail
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])
    assert_failure response, 'Transaction should fail'
    assert_equal "Failure", response.transaction['status'], 'Transaction should fail'
  end
  
  # payment of 700 should be unknown at issuer
  def test_transaction_expired       
    # first setup the payment
    response = @gateway.setup_purchase(700, @options)

    # now try to authorize the payment, issuer simulator lets the payment fail
    response = @gateway.capture(:transaction_id => response.transaction['transactionID'])

    assert_failure response, 'Transaction should fail'
    assert_equal "SO1000", response.error[ 'errorCode'], 'ErrorCode should be correct'
  end
  
  
end 