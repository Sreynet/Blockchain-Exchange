pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./Token.sol"; //work for any ECR20 token
// Deposit & Withdraw Funds
// Manage Orders - Make or Cancel
// Handle Tokens

//TODO
//[] Set the fee account
//[] Deposit Ether
//[] Withdraw Ether
//[] Deposit Tokens
//[] Withdraw tokens
//[] Check balances
//[] Make order
//[] Cancel order
//[] Fill order
//[] Charge fees

contract Exchange{
	using SafeMath for uint;
	//variables
	address public feeAccount; //the account that receives exchange fees
	uint256 public feePercent;
	address constant ETHER = address(0); // store Ether in tokens mapping with blank address
	mapping(address => mapping(address => uint256)) public tokens; //token address, address of user, number of tokens
    mapping(uint256 => _Order) public orders;
    uint256 public orderCount;
    mapping(uint256 => bool) public orderCancelled;
    mapping(uint256 => bool) public orderFilled;

    //Events
    event Deposit (address token, address user, uint256 amount, uint256 balance);
    event Withdraw(address token, address user, uint256 amount, uint balance);
    event Order( //Order without  "_" will be used outside contract
    	uint id,
    	address user,
    	address tokenGet,
    	uint amountGet,
    	address tokenGive,
    	uint amountGive,
    	uint timestamp


    );

     event Cancel(
     	uint id,
    	address user,
    	address tokenGet,
    	uint amountGet,
    	address tokenGive,
    	uint amountGive,
    	uint timestamp


    );
     event Trade(
     uint256 id,
     address user,
     address tokenGet,
     uint256 amountGet,
     address tokenGive,
     uint256 amountGive,
     address userFill,
     uint timestamp
     	);

    // A way to Model the order
    // A way to store the order
    // A way to add the order to storage

    struct _Order {   // _Order with "_" will be used only inside contract
    	uint id;
    	address user;
    	address tokenGet;
    	uint amountGet;
    	address tokenGive;
    	uint amountGive;
    	uint timestamp;


    }

    

	constructor(address _feeAccount, uint256 _feePercent) public {
		feeAccount = _feeAccount;
		feePercent = _feePercent;
	}

	//Fallback: reverts if Ether is sent to this smart contract by mistake
	function() external{
		revert();
	}

	function depositEther() payable public { // need payable for it to work
		tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].add(msg.value);
		emit Deposit(ETHER, msg.sender, msg.value, tokens[ETHER][msg.sender]);

	}

	function withdrawEther(uint _amount) public {
		require(tokens[ETHER][msg.sender] >= _amount);
		tokens[ETHER][msg.sender] = tokens[ETHER][msg.sender].sub(_amount);
	     msg.sender.transfer(_amount);
	     emit Withdraw(ETHER, msg.sender, _amount, tokens[ETHER][msg.sender]);
	    

	}
	function depositToken(address _token, uint256 _amount) public {
        //Don't allow Ether deposits
        require(_token != ETHER);
		//Which token?
		//How much?
		//Send tokens to this contract
		require(Token(_token).transferFrom(msg.sender, address(this), _amount)); // instance of token on ethereum network
        //Manage deposit - update balance
        tokens[_token][msg.sender] = tokens[_token][msg.sender].add(_amount); //uses mapping from before
		//Emit event
		emit Deposit(_token, msg.sender, _amount, tokens[_token][msg.sender]);
	}
	function withdrawToken(address _token, uint256 _amount) public {
		require(_token != ETHER);
		require(tokens[_token][msg.sender] >= _amount);

		tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
		require(Token(_token).transfer(msg.sender, _amount));
		emit Withdraw(_token, msg.sender, _amount, tokens[_token][msg.sender]);
	}
	function balanceOf(address _token, address _user) public view returns (uint256 ){
		return tokens[_token][_user];
	}
	function makeOrder(address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) public {
        orderCount = orderCount.add(1);
		orders[orderCount] = _Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
        emit Order(orderCount, msg.sender, _tokenGet, _amountGet, _tokenGive, _amountGive, now);
	}

	function cancelOrder(uint256 _id) public {
		_Order storage _order = orders[_id];
		require(address(_order.user) == msg.sender);
		require(_order.id == _id);
		// Must be "my" order
		// Must be a valid order

		orderCancelled[_id] = true;
		emit Cancel(_order.id, msg.sender, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive, now);
	}
	function fillOrder(uint256 _id) public{
		require(_id > 0 && _id <= orderCount);
		require(!orderFilled[_id]);
        require(!orderCancelled[_id]);
		_Order storage _order = orders[_id];
		_trade(_order.id, _order.user, _order.tokenGet, _order.amountGet, _order.tokenGive, _order.amountGive);
		orderFilled[_order.id] = true;
		//Mark order as filled
	}
	function _trade(uint256 _orderId, address _user, address _tokenGet, uint256 _amountGet, address _tokenGive, uint256 _amountGive) internal { //internal allows function to only be used inside smart contract
        //Execute trade
		//Charge fees
		//Emit trade event
		 uint256 _feeAmount = _amountGet.mul(feePercent).div(100);

        tokens[_tokenGet][msg.sender] = tokens[_tokenGet][msg.sender].sub(_amountGet.add(_feeAmount)); //msg.sender is filling the order
        tokens[_tokenGet][_user] = tokens[_tokenGet][_user].add(_amountGet); //amountGet goes into user balance , user creates the order
        tokens[_tokenGet][feeAccount] = tokens[_tokenGet][feeAccount].add(_feeAmount);
        tokens[_tokenGive][_user] = tokens[_tokenGive][_user].sub(_amountGive);
        tokens[_tokenGive][msg.sender] = tokens[_tokenGive][msg.sender].add(_amountGive);

        emit Trade(_orderId, _user, _tokenGet, _amountGet, _tokenGive, _amountGive, msg.sender, now);

	}
}