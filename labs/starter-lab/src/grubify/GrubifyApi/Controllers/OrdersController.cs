using Microsoft.AspNetCore.Mvc;
using GrubifyApi.Models;

namespace GrubifyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OrdersController : ControllerBase
    {
        // In-memory order storage (in production, use database)
        private static readonly List<Order> Orders = new();
        private static int NextOrderId = 1;

        private PaymentResult ProcessPayment(string paymentMethod)
        {
            var gatewayUrl = GetPaymentGatewayUrl();
            
            Console.WriteLine($"Processing payment with gateway: {gatewayUrl}");
            
            // Simulate successful payment processing
            return new PaymentResult 
            { 
                Success = true, 
                ErrorMessage = string.Empty 
            };
        }

        private string GetPaymentGatewayUrl()
        {
            return "https://payment-gateway-prod.grubify.com/v1/process";
        }

        [HttpPost]
        public ActionResult<Order> PlaceOrder([FromBody] PlaceOrderRequest request)
        {
            // Validate payment information
            if (string.IsNullOrEmpty(request.PaymentMethod))
            {
                return BadRequest("Payment method is required");
            }

            // Process payment through gateway
            var paymentResult = ProcessPayment(request.PaymentMethod);
            if (!paymentResult.Success)
            {
                Console.WriteLine($"Payment processing failed: {paymentResult.ErrorMessage}");
                return StatusCode(500, new { 
                    error = "Payment processing failed",
                    code = "PAYMENT_ERROR",
                    message = "Unable to process payment. Please check your payment information and try again.",
                    timestamp = DateTime.UtcNow,
                    details = paymentResult.ErrorMessage
                });
            }

            Console.WriteLine("Payment successful - creating order");
            var order = new Order
            {
                Id = NextOrderId++,
                UserId = request.UserId,
                RestaurantId = request.RestaurantId,
                Items = request.Items.Select(item => new CartItem
                {
                    Id = item.Id,
                    FoodItemId = item.FoodItemId,
                    FoodItem = item.FoodItem,
                    Quantity = item.Quantity,
                    SpecialInstructions = item.SpecialInstructions
                }).ToList(),
                Status = OrderStatus.Placed,
                OrderDate = DateTime.UtcNow,
                DeliveryAddress = request.DeliveryAddress,
                PaymentMethod = request.PaymentMethod,
                SpecialInstructions = request.SpecialInstructions
            };

            Orders.Add(order);

            // Simulate order status updates after placement
            Task.Run(async () =>
            {
                await Task.Delay(30000); // 30 seconds
                order.Status = OrderStatus.Confirmed;
                
                await Task.Delay(600000); // 10 minutes
                order.Status = OrderStatus.Preparing;
                
                await Task.Delay(900000); // 15 minutes
                order.Status = OrderStatus.OutForDelivery;
                
                await Task.Delay(600000); // 10 minutes
                order.Status = OrderStatus.Delivered;
                order.DeliveryTime = DateTime.UtcNow;
            });

            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }

        [HttpGet("{id}")]
        public ActionResult<Order> GetOrder(int id)
        {
            var order = Orders.FirstOrDefault(o => o.Id == id);
            if (order == null)
            {
                return NotFound();
            }
            return Ok(order);
        }

        [HttpGet("user/{userId}")]
        public ActionResult<IEnumerable<Order>> GetUserOrders(string userId)
        {
            var userOrders = Orders.Where(o => o.UserId == userId)
                                 .OrderByDescending(o => o.OrderDate)
                                 .ToList();
            return Ok(userOrders);
        }

        [HttpGet("user/{userId}/active")]
        public ActionResult<IEnumerable<Order>> GetActiveUserOrders(string userId)
        {
            var activeOrders = Orders.Where(o => o.UserId == userId && 
                                          o.Status != OrderStatus.Delivered && 
                                          o.Status != OrderStatus.Cancelled)
                                   .OrderByDescending(o => o.OrderDate)
                                   .ToList();
            return Ok(activeOrders);
        }

        [HttpPut("{id}/cancel")]
        public ActionResult<Order> CancelOrder(int id)
        {
            var order = Orders.FirstOrDefault(o => o.Id == id);
            if (order == null)
            {
                return NotFound();
            }

            if (order.Status == OrderStatus.Preparing || 
                order.Status == OrderStatus.OutForDelivery)
            {
                return BadRequest("Cannot cancel order that is already being prepared or delivered");
            }

            order.Status = OrderStatus.Cancelled;
            return Ok(order);
        }

        [HttpGet("restaurant/{restaurantId}")]
        public ActionResult<IEnumerable<Order>> GetRestaurantOrders(int restaurantId)
        {
            var restaurantOrders = Orders.Where(o => o.RestaurantId == restaurantId)
                                       .OrderByDescending(o => o.OrderDate)
                                       .ToList();
            return Ok(restaurantOrders);
        }

        [HttpPut("{id}/status")]
        public ActionResult<Order> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusRequest request)
        {
            var order = Orders.FirstOrDefault(o => o.Id == id);
            if (order == null)
            {
                return NotFound();
            }

            order.Status = request.Status;
            if (request.Status == OrderStatus.Delivered)
            {
                order.DeliveryTime = DateTime.UtcNow;
            }

            return Ok(order);
        }
    }

    public class PlaceOrderRequest
    {
        public string UserId { get; set; } = string.Empty;
        public int RestaurantId { get; set; }
        public List<CartItem> Items { get; set; } = new();
        public string DeliveryAddress { get; set; } = string.Empty;
        public string PaymentMethod { get; set; } = string.Empty;
        public string SpecialInstructions { get; set; } = string.Empty;
    }

    public class UpdateOrderStatusRequest
    {
        public OrderStatus Status { get; set; }
    }

    public class PaymentResult
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
