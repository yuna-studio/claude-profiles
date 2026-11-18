// The account row above the prompt: every ccp account with its limits. ctrl+x tab puts the keyboard on it, the arrows
// pick one, Enter runs `ccp sw <n>`: the conversation moves to that account once the turn ends.
import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Account } from '../types'

const accounts = atom({ plugin: 'ccp', key: 'accounts' } as const, [] as Account[])
const hint = atom({ plugin: 'ccp', key: 'hint' } as const, '')

const ccp = ($: EngineInterface) => `${$.plugin.root}/bin/ccp`

const load = async ($: EngineInterface) => {
  const ran = await $.process.run([ccp($), 'prompt', '--tsv'], { env: { CLAUDECODE: '1' }, timeoutMs: 10000 }).catch(() => null)
  if (!ran || ran.exitCode !== 0) {
    return
  }
  const list: Account[] = []
  let words = ''
  for (const line of ran.stdout.split('\n')) {
    const [a, b, c, d] = line.split('\t')
    if (a === '#hint') {
      words = b ?? ''
    } else if (a && b) {
      list.push({ n: Number(a), id: b, isThis: c === '1', text: d ?? '' })
    }
  }
  await update($, accounts, () => list)
  await update($, hint, () => words)
}

export const register: Register = on => {
  let stop: (() => void) | undefined

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await load($)
    stop?.()
    stop = $.clock.every(60_000, () => {
      void load($)
    })
    return started
  })

  on('turn.complete', async ($, e, next) => {
    void load($)
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, accounts)
    if (list.length < 2 || e.props.hasSurvey) {
      return next(e)
    }
    const words = await read($, hint)
    const { Box, Button, Text } = $.ui.resolve(e)

    return (
      <Box>
        {list.map(a => (
          <Button
            key={`account:${a.n}`}
            label={`${a.isThis ? '▶ ' : ''}#${a.n}${a.text ? ` ${a.text}` : ''}`}
            onPress={async () => {
              if (a.isThis) {
                $.ui.toast(`#${a.n}`)
                return
              }
              const ran = await $.process
                .run([ccp($), 'sw', String(a.n)], { env: { CLAUDECODE: '1' }, timeoutMs: 15000 })
                .catch(() => null)
              const said = `${ran?.stdout ?? ''}${ran?.stderr ?? ''}`.trim().replace(/^ccp: /, '')
              $.ui.toast(said || `ccp sw ${a.n} did not start`)
            }}
          />
        ))}
        <Text dimColor> {words}</Text>
      </Box>
    )
  })
}
