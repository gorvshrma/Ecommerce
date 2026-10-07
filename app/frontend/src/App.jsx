
import { useEffect, useMemo, useState } from "react";

const API = import.meta.env.VITE_API_URL || "http://localhost:8000";

const money = (value) =>
  new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);

export default function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState([]);
  const [info, setInfo] = useState(null);
  const [health, setHealth] = useState("checking");
  const [message, setMessage] = useState("");

  async function load() {
    try {
      const [productRes, infoRes, healthRes] = await Promise.all([
        fetch(`${API}/api/products`),
        fetch(`${API}/info`),
        fetch(`${API}/health`),
      ]);
      setProducts(await productRes.json());
      setInfo(await infoRes.json());
      setHealth((await healthRes.json()).status);
    } catch {
      setHealth("unavailable");
    }
  }

  useEffect(() => { load(); }, []);

  function addToCart(product) {
    setCart((items) => {
      const existing = items.find((item) => item.id === product.id);
      if (existing) {
        return items.map((item) =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      return [...items, { ...product, quantity: 1 }];
    });
  }

  const total = useMemo(
    () => cart.reduce((sum, item) => sum + item.price * item.quantity, 0),
    [cart]
  );

  async function placeOrder() {
    if (!cart.length) return;
    setMessage("Placing order...");

    const response = await fetch(`${API}/api/orders`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        customer_name: "Demo User",
        customer_email: "demo@example.com",
        items: cart.map((item) => ({
          product_id: item.id,
          quantity: item.quantity,
        })),
      }),
    });

    if (response.ok) {
      const order = await response.json();
      setMessage(`Order #${order.id} created successfully`);
      setCart([]);
      load();
    } else {
      const error = await response.json();
      setMessage(error.detail || "Order failed");
    }
  }

  return (
    <div className="page">
      <header className="nav">
        <div>
          <div className="brand">CloudCart</div>
          <div className="subtitle">Cloud-native 3-tier commerce platform</div>
        </div>
        <div className="status">
          <span className={`dot ${health === "healthy" ? "ok" : ""}`} />
          API {health}
        </div>
      </header>

      <section className="hero">
        <div>
          <p className="eyebrow">DEVOPS PORTFOLIO PROJECT</p>
          <h1>Built for the cloud.<br />Engineered for operations.</h1>
          <p className="heroCopy">
            React, FastAPI and PostgreSQL today. Docker, CI/CD,
            Terraform, EKS, GitOps and observability next.
          </p>
        </div>
        <div className="runtimeCard">
          <span>Runtime</span>
          <strong>{info?.environment || "local"}</strong>
          <small>v{info?.version || "1.0.0"} · {info?.git_commit || "unknown"}</small>
          <small>{info?.hostname || "backend"}</small>
        </div>
      </section>

      <main className="layout">
        <section>
          <div className="sectionTitle">
            <div>
              <p className="eyebrow">CATALOG</p>
              <h2>Engineering essentials</h2>
            </div>
            <span>{products.length} products</span>
          </div>

          <div className="products">
            {products.map((product) => (
              <article className="product" key={product.id}>
                <div className="productVisual">
                  {product.name.split(" ").slice(0, 2).map((w) => w[0]).join("")}
                </div>
                <div className="productBody">
                  <h3>{product.name}</h3>
                  <p>{product.description}</p>
                  <div className="productMeta">
                    <strong>{money(product.price)}</strong>
                    <span>{product.stock} in stock</span>
                  </div>
                  <button onClick={() => addToCart(product)}>Add to cart</button>
                </div>
              </article>
            ))}
          </div>
        </section>

        <aside className="cart">
          <p className="eyebrow">ORDER</p>
          <h2>Cart</h2>

          {!cart.length ? (
            <div className="empty">Your cart is empty.</div>
          ) : (
            <div className="cartItems">
              {cart.map((item) => (
                <div className="cartItem" key={item.id}>
                  <div>
                    <strong>{item.name}</strong>
                    <small>Qty {item.quantity}</small>
                  </div>
                  <span>{money(item.price * item.quantity)}</span>
                </div>
              ))}
            </div>
          )}

          <div className="total">
            <span>Total</span>
            <strong>{money(total)}</strong>
          </div>

          <button className="checkout" onClick={placeOrder} disabled={!cart.length}>
            Place demo order
          </button>

          {message && <p className="message">{message}</p>}

          <div className="ops">
            <span>Operational endpoints</span>
            <code>/health</code>
            <code>/ready</code>
            <code>/metrics</code>
          </div>
        </aside>
      </main>
    </div>
  );
}
