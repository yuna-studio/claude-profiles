import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'ccp',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isCollapsed: false, isWorking: false, maxRows: 3 },
} as const

const TSV = '#hint\tswitch: ctrl+x tab, arrows, Enter\n1\tdefault\t1\twk 98%\n2\tacct-2\t0\t5h 3% wk 17%\n'

test('the row lists every account and Enter on one runs ccp sw', async ($, on) => {
  const ran: string[][] = []
  on('process.run', (_, e) => {
    ran.push([...e.argv])
    const stdout = e.argv[1] === 'prompt' ? TSV : 'switching to #2: when this turn ends, this conversation reopens there\n'
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('clock.every', () => ({ value: undefined }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  const toasts: string[] = []
  on('ui.toast', (_, e) => {
    toasts.push(String(e.text))
    return { value: undefined }
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })

  expect((await ui.find({ type: 'Button', key: 'account:1' }))?.text).toBe('▶ #1 wk 98%')
  expect((await ui.find({ type: 'Button', key: 'account:2' }))?.text).toBe('#2 5h 3% wk 17%')
  await ui.press({ key: 'account:2' })
  expect(ran.some(a => a[1] === 'sw' && a[2] === '2')).toBe(true)
  expect(toasts.some(t => t.startsWith('switching to #2'))).toBe(true)
  await ui.unmount()
})

test('one account: no row', async ($, on) => {
  on('process.run', () => ({
    value: { exitCode: 0, stdout: '#hint\tx\n1\tdefault\t1\t\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('clock.every', () => ({ value: undefined }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  await ui.unmount()
})
