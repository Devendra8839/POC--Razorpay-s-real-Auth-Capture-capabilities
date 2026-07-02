content = File.read("app/views/customer_dashboard/index.html.erb")

new_js = <<~JS
  handler: function(response) {
          if (type === 'rental') {
            captureRentalPayment(response.razorpay_payment_id, rentalId, amount);
          } else {
            fetch('/api/payments/sync_security_authorization', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content },
              body: JSON.stringify({ rental_id: rentalId, payment_id: response.razorpay_payment_id })
            }).then(() => {
              alert('Security deposit authorized successfully!');
              location.reload();
            });
          }
        },
JS

content = content.sub(/handler: function\(response\) \{(.*?)\},/m, new_js.strip + ",")

File.write("app/views/customer_dashboard/index.html.erb", content)
