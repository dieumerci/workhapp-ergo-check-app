import { createInertiaApp } from '@inertiajs/react'
import AppLayout from '@/layouts/AppLayout'
import AuthLayout from '@/layouts/AuthLayout'

void createInertiaApp({
  pages: '../pages',

  strictMode: true,

  // Signed-out pages get the centred card; everything else gets the app shell.
  layout: (name) => (name.startsWith('sessions/') ? AuthLayout : AppLayout),

  title: (title) => (title ? `${title} · ErgoCheck` : 'ErgoCheck'),

  progress: { color: '#0E6B5C' },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => {
      return { queryStringArrayFormat: 'brackets' }
    },
  },
}).catch((error) => {
  // This ensures this entrypoint is only loaded on Inertia pages
  // by checking for the presence of the root element (#app by default).
  if (document.getElementById('app')) {
    throw error
  } else {
    console.error(
      'Missing root element.\n\n' +
        'If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n' +
        'Consider moving <%= vite_typescript_tag "inertia.tsx" %> to the Inertia-specific layout instead.',
    )
  }
})
