import { useState } from 'react'
import logo from './logo.svg'
import './App.css'

function Home() {
  const [count, setCount] = useState(0)
  const env_test = import.meta.env.VITE_TEST

  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>Hello, CommuniTEA!</p>
        <p>
          <button type="button" onClick={() => setCount((count) => count + 1)}>
            count is: {count}
          </button>
        </p>
        <p>
          This is a test page to indicate that CI/CD with GitHub has been set up. Enable the repo's workflow and the site will come to life!
          {env_test ? <p>The env is working, too!</p> : <p>env not loaded</p>}
        </p>

        <p>
          <a
            className="App-link"
            href="https://reactjs.org"
            target="_blank"
            rel="noopener noreferrer"
          >
            Learn React
          </a>
          {' | '}
          <a
            className="App-link"
            href="https://vitejs.dev/guide/features.html"
            target="_blank"
            rel="noopener noreferrer"
          >
            Vite Docs
          </a>
        </p>
      </header>
    </div>
  )
}

export default Home
